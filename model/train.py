"""Will a Florida county get FEMA Individual Assistance for a given storm?

Reads marts.ml_storm_county_features, evaluates three approaches two ways, and writes
out-of-fold predictions back to the warehouse (marts.ml_predictions) plus model/metrics.json.

- baseline rule: storm passed within 100 km with hurricane-force wind (>= 64 kt) nearby
- logistic regression (scaled)
- gradient-boosted trees (HistGradientBoostingClassifier)

Evaluation:
- grouped CV: 5 folds split by storm, so a storm is never in both train and test
- time split: train on seasons < 2020, test on 2020+ (Sally, Ian, Nicole, Idalia, Debby, Helene, Milton)
"""
import json
from pathlib import Path

import duckdb
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss, f1_score, roc_auc_score
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).parent.parent
DB = ROOT / "data" / "warehouse.duckdb"
FEATURES = ["min_distance_km", "wind_at_closest_kt", "max_wind_within_100km_kt",
            "max_wind_within_200km_kt", "hours_within_200km", "landfall_within_100km", "log_population", "water_share"]
TIME_SPLIT = 2020


def models():
    return {
        "logistic_regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=1000, class_weight="balanced")),
        "gradient_boosting": HistGradientBoostingClassifier(max_depth=3, learning_rate=0.05, max_iter=300,
                                                            class_weight="balanced", random_state=0),
    }


def baseline(X):
    """Hand rule an analyst might use: hurricane-force wind passed within 100 km."""
    return (X[:, FEATURES.index("max_wind_within_100km_kt")] >= 64).astype(float)


def scores(y, p):
    return {"roc_auc": round(roc_auc_score(y, p), 3),
            "pr_auc": round(average_precision_score(y, p), 3),
            "f1_at_0.5": round(f1_score(y, p >= 0.5), 3),
            "brier": round(brier_score_loss(y, np.clip(p, 0, 1)), 3)}


def main():
    con = duckdb.connect(str(DB))
    df = con.sql(f"select storm_county_key, storm_id, storm_name, season, county_fips, county_name, ia_declared, "
                 f"{', '.join(FEATURES)} from marts.ml_storm_county_features").fetchnumpy()
    X = np.column_stack([df[f].astype(float) for f in FEATURES])
    y = df["ia_declared"].astype(int)
    storms, seasons = df["storm_id"], df["season"]
    print(f"{len(y):,} storm×county rows, {y.sum():,} positives, {len(set(storms))} storms")

    metrics = {"rows": int(len(y)), "positives": int(y.sum()), "storms": len(set(storms)), "features": FEATURES}

    # grouped CV by storm -> out-of-fold predictions for every row
    oof = {name: np.zeros(len(y)) for name in models()}
    for train, test in GroupKFold(n_splits=5).split(X, y, storms):
        for name, m in models().items():
            oof[name][test] = m.fit(X[train], y[train]).predict_proba(X[test])[:, 1]
    metrics["grouped_cv"] = {"baseline_rule": scores(y, baseline(X)),
                             **{name: scores(y, p) for name, p in oof.items()}}

    # time split
    tr, te = seasons < TIME_SPLIT, seasons >= TIME_SPLIT
    metrics["time_split"] = {"train_seasons": f"2000-{TIME_SPLIT - 1}", "test_seasons": f"{TIME_SPLIT}+",
                             "test_rows": int(te.sum()), "test_positives": int(y[te].sum()),
                             "baseline_rule": scores(y[te], baseline(X[te]))}
    fitted = {}
    for name, m in models().items():
        fitted[name] = m.fit(X[tr], y[tr])
        metrics["time_split"][name] = scores(y[te], m.predict_proba(X[te])[:, 1])

    # which features drive the primary (logistic) model (on the held-out seasons)
    imp = permutation_importance(fitted["logistic_regression"], X[te], y[te], scoring="roc_auc", n_repeats=10, random_state=0)
    metrics["feature_importance"] = dict(sorted(
        ((f, round(float(v), 4)) for f, v in zip(FEATURES, imp.importances_mean)), key=lambda kv: -kv[1]))

    # per-storm view for the 2020+ storms: how many IA counties the model caught
    p_te = fitted["logistic_regression"].predict_proba(X[te])[:, 1]
    per_storm = {}
    for sid in sorted(set(storms[te])):
        mask = storms[te] == sid
        actual, pred = y[te][mask], p_te[mask] >= 0.5
        per_storm[str(df["storm_name"][te][mask][0])] = {
            "season": int(seasons[te][mask][0]), "counties_with_ia": int(actual.sum()),
            "predicted": int(pred.sum()), "caught": int((actual & pred).sum()), "false_alarms": int((~actual.astype(bool) & pred).sum())}
    metrics["time_split_by_storm"] = per_storm

    (ROOT / "model" / "metrics.json").write_text(json.dumps(metrics, indent=2))
    print(json.dumps({k: metrics[k] for k in ("grouped_cv", "time_split")}, indent=2))

    # out-of-fold predictions back into the warehouse for the dashboard
    con.execute("create or replace table marts.ml_predictions (storm_county_key varchar, p_ia_gradient_boosting double, p_ia_logistic double)")
    con.executemany("insert into marts.ml_predictions values (?, ?, ?)",
                    list(zip(df["storm_county_key"].tolist(), oof["gradient_boosting"].tolist(), oof["logistic_regression"].tolist())))


if __name__ == "__main__":
    main()
