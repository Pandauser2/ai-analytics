"""
North Star (core adoption) dashboard — Streamlit over **BigQuery** cleaned views.

**Data source:** view ``kpi_north_star_subscriber_detail`` (see ``sql/kpi_views.sql``).
That view already:
  - Restricts to **subscribers** (``first_subscription_date IS NOT NULL``).
  - Applies the same **DQ row filters** as other KPI views: rows with
    ``dq_subscription_before_signup`` or ``dq_cancel_before_subscription`` are
    **excluded** in SQL — the app does not re-implement those rules in Python.
  - Joins ``fct_usage_clean`` and computes core-action / North Star booleans.

**North Star in the UI:** mean of ``north_star_both_core`` over the subscriber
rows returned (optionally filtered by channel in the app).

**Viz:** ``pandas`` for slicing/aggregates; **Plotly** for charts.

**Config:** ``PROJECT_ID`` / ``DATASET`` env vars (same as ``setup_bigquery.sh``),
``BIGQUERY_PROJECT`` / ``BIGQUERY_DATASET`` in ``.streamlit/secrets.toml``, and/or
leave the sidebar project blank to use the **default project** from Application
Default Credentials (``GOOGLE_CLOUD_PROJECT``, ``gcloud config set project``, etc.).

**Run:** ``streamlit run streamlit_north_star_app.py``

**Dependency:** ``google-cloud-bigquery`` (see ``requirements.txt``). Import is
deferred until the first query so a missing install yields a clear message in
the app instead of failing at import time.
"""
from __future__ import annotations

import os
import re
import sys
from typing import Optional, Tuple

import pandas as pd
import plotly.express as px
import streamlit as st

# Must match the action_type_id filters inside ``kpi_north_star_subscriber_detail``
# in ``sql/kpi_views.sql`` (used for metric help text only; logic lives in BQ).
CORE_ACTION_IDS = (1, 3)

_VIEW_NAME = "kpi_north_star_subscriber_detail"


def _valid_dataset_id(value: str) -> bool:
    """BigQuery dataset id: letter or underscore, then alphanumeric/underscore."""
    return bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,1023}", value))


def _valid_project_id(value: str) -> bool:
    """
    GCP project id (6–30 chars): starts with a letter, ends with letter or digit,
    middle is letters, digits, hyphens. User input is normalized to lowercase first.
    """
    return bool(re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", value))


def _bq_config_from_env_and_secrets() -> Tuple[str, str]:
    """
    Default project/dataset for sidebar text inputs.

    Precedence: Streamlit secrets (if ``secrets.toml`` exists), then environment.
    Matches the shell script convention: ``PROJECT_ID``, ``DATASET``.
    """
    project = (
        os.environ.get("PROJECT_ID")
        or os.environ.get("GOOGLE_CLOUD_PROJECT")
        or os.environ.get("GCP_PROJECT")
        or os.environ.get("GCLOUD_PROJECT")
        or ""
    ).strip()
    dataset = (os.environ.get("DATASET") or "analytics").strip()

    try:
        project = (
            st.secrets.get("BIGQUERY_PROJECT")
            or st.secrets.get("BIGQUERY_PROJECT_ID")
            or st.secrets.get("GCP_PROJECT")
            or project
        ).strip()
        dataset = (st.secrets.get("BIGQUERY_DATASET") or st.secrets.get("BQ_DATASET") or dataset).strip()
    except FileNotFoundError:
        pass

    return project, dataset


def _fully_qualified_view(project_id: str, dataset: str) -> str:
    """Backtick-wrapped table id for SQL (``project``/``dataset`` validated before call)."""
    return f"`{project_id}.{dataset}.{_VIEW_NAME}`"


def _bigquery_client(project_id: Optional[str]):
    """Import ``google.cloud.bigquery`` lazily so ``streamlit run`` can start without it installed."""
    try:
        from google.cloud import bigquery
    except ImportError as exc:
        py = sys.executable
        raise ImportError(
            "Missing the BigQuery client library. Install it into **the same Python** "
            "that is running this app (Streamlit often uses a different interpreter than "
            "your terminal ``python3``).\n\n"
            f"    `{py} -m pip install -r requirements.txt`\n\n"
            "Or only BigQuery:\n\n"
            f"    `{py} -m pip install google-cloud-bigquery`\n\n"
            "Then restart Streamlit. Prefer launching with "
            "``python3 -m streamlit run streamlit_north_star_app.py`` so pip and Streamlit "
            "match the same interpreter."
        ) from exc
    # project=None → library uses ADC / GOOGLE_CLOUD_PROJECT / gcloud default project.
    return bigquery.Client(project=project_id or None)


@st.cache_data(ttl=120, show_spinner=True)
def _load_subscriber_detail(project_id: str, dataset: str) -> Tuple[pd.DataFrame, str]:
    """
    Pull the full subscriber-level North Star dataset from BigQuery.

    ``project_id`` may be empty: the client resolves the billing/default project
    (``client.project``), which is then used in the fully-qualified table name.

    Returns ``(dataframe, resolved_project_id)`` for accurate UI labels.
    """
    dataset = dataset.strip()
    raw = (project_id or "").strip().lower()
    if raw and not _valid_project_id(raw):
        raise ValueError(
            "Invalid GCP project id format. Use 6–30 characters: lowercase letters, digits, "
            "hyphens; must start with a letter and end with a letter or digit."
        )
    if not _valid_dataset_id(dataset):
        raise ValueError("Invalid BigQuery dataset id (letters, numbers, underscore).")

    client = _bigquery_client(raw or None)
    resolved = (client.project or "").strip()
    if not resolved:
        raise ValueError(
            "Could not determine GCP project id. Either enter your **GCP project id** in the "
            "sidebar, or set **GOOGLE_CLOUD_PROJECT** / **PROJECT_ID** before starting Streamlit, "
            "or add **BIGQUERY_PROJECT** to ``.streamlit/secrets.toml``. "
            "With gcloud: ``gcloud config set project YOUR_PROJECT_ID`` then ensure ADC is set."
        )

    sql = f"SELECT * FROM {_fully_qualified_view(resolved, dataset)}"
    df = client.query(sql).result().to_dataframe()
    return df, resolved


def _chart_height_px(n_channels: int) -> int:
    """Vertical pixel height for horizontal bar charts so labels are readable."""
    n = max(1, n_channels)
    return int(56 * n + 90)


def main() -> None:
    st.set_page_config(page_title="North Star (Core Actions)", layout="wide")
    st.title("North Star dashboard (core actions 1 and 3)")
    st.markdown(
        "**Data:** BigQuery view **`"
        + _VIEW_NAME
        + "`** (DQ + subscriber logic in SQL). **Charts:** Plotly."
    )

    # --- Sidebar: connection defaults, manual refresh (clears Streamlit cache only) ---
    default_project, default_dataset = _bq_config_from_env_and_secrets()

    with st.sidebar:
        st.header("BigQuery")
        project_id = st.text_input(
            "GCP project id (optional)",
            value=default_project,
            help=(
                "If empty, the BigQuery client uses your **default project** from ADC "
                "(e.g. GOOGLE_CLOUD_PROJECT or `gcloud config get-value project`)."
            ),
        ).strip()
        dataset = st.text_input("Dataset", value=default_dataset).strip()
        if st.button("Refresh data (clear cache)"):
            st.cache_data.clear()
            st.rerun()
        st.divider()
        st.caption(
            "Auth: **Application Default Credentials** (ADC). One-time setup in a terminal: "
            "``gcloud auth application-default login``. "
            "Or set ``GOOGLE_APPLICATION_CREDENTIALS`` to a service-account JSON path. "
            "Needs BigQuery **job create** + **read** on the project."
        )

    try:
        df, resolved_project = _load_subscriber_detail(project_id, dataset)
    except ImportError as exc:
        st.error(str(exc))
        st.stop()
    except Exception as exc:  # noqa: BLE001 — BQ/auth/network/API errors
        err_lower = str(exc).lower()
        if (
            "default credentials" in err_lower
            or "credentials were not found" in err_lower
            or "could not automatically determine credentials" in err_lower
        ):
            st.markdown("#### Application Default Credentials not found")
            st.markdown(
                "BigQuery needs ADC for **this** Python process (the one running Streamlit). "
                "In a normal terminal (not inside the app), run:"
            )
            st.code("gcloud auth application-default login", language="bash")
            st.markdown(
                "Then set your project if the sidebar id is empty:"
            )
            st.code(
                "gcloud config set project YOUR_PROJECT_ID\nexport GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID",
                language="bash",
            )
            st.markdown(
                "Official guide: "
                "[Set up Application Default Credentials]"
                "(https://cloud.google.com/docs/authentication/external/set-up-adc). "
                "For CI or servers, use a service account and "
                "``GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json`` instead."
            )
            st.caption(f"Original error: `{exc}`")
        else:
            st.error(f"Could not load from BigQuery: {exc}")
        st.stop()

    st.sidebar.caption(f"Queries run in project: **{resolved_project}**")

    # --- Channel filter (app-only slice; does not change the view) ---
    channels = sorted(df["channel"].dropna().unique().tolist())
    selected_channels = st.sidebar.multiselect(
        "Channel filter",
        options=channels,
        default=channels,
        help="Restrict the subscriber universe to these marketing channels.",
    )
    if not selected_channels:
        st.error("Select at least one channel.")
        st.stop()

    df_sub = df[df["channel"].isin(selected_channels)].copy()
    n_sub = len(df_sub)
    if n_sub == 0:
        st.error("No subscribers after channel filter. Adjust channel selection.")
        st.stop()

    # Headline = simple mean of the precomputed boolean column from the view.
    ns_rate = float(df_sub["north_star_both_core"].mean())
    churn_rate = float(df_sub["has_cancel_date"].mean())

    # Churn split for diagnostics (cancel_date present); same boolean as in the view.
    not_churned = df_sub[~df_sub["has_cancel_date"]]
    churned = df_sub[df_sub["has_cancel_date"]]

    # --- Primary row: headline metric + North Star by channel (Plotly) ---
    top1, top2 = st.columns([1, 3], gap="large")
    with top1:
        st.metric(
            label="North Star (headline)",
            value=f"{ns_rate:.1%}",
            help=(
                "Share of subscribers who adopted BOTH core actions "
                f"{CORE_ACTION_IDS[0]} and {CORE_ACTION_IDS[1]} "
                "(see view SQL for exact definition)."
            ),
        )
        st.caption(f"Based on **{n_sub:,}** subscribers after channel filter.")

    with top2:
        st.subheader("North Star by channel")
        # One row per channel in the current filter; rates are means of view booleans.
        ch_agg = (
            df_sub.groupby("channel", as_index=False)
            .agg(
                subscribers=("customerid", "count"),
                north_star=("north_star_both_core", "mean"),
                adopt_action_1=("adopted_action_1", "mean"),
                adopt_action_3=("adopted_action_3", "mean"),
                churn_proxy=("has_cancel_date", "mean"),
            )
            .sort_values("north_star", ascending=True)
        )

        fig = px.bar(
            ch_agg,
            x="north_star",
            y="channel",
            orientation="h",
            color_discrete_sequence=["#2563eb"],
            labels={"north_star": "North Star", "channel": "Channel"},
            hover_data=["subscribers", "north_star", "adopt_action_1", "adopt_action_3", "churn_proxy"],
        )
        # Benchmark each bar against the headline (same filtered ``df_sub``).
        fig.add_vline(
            x=ns_rate,
            line_width=2,
            line_dash="dash",
            line_color="#64748b",
            annotation_text="Overall",
            annotation_position="top",
        )
        fig.update_layout(
            height=_chart_height_px(len(ch_agg)),
            margin=dict(l=24, r=24, t=40, b=40),
            xaxis=dict(tickformat=".0%", range=[0, 1], title="North Star (%)"),
            yaxis=dict(title=""),
            showlegend=False,
        )
        st.plotly_chart(fig, use_container_width=True)
        st.caption(
            "Dashed vertical line = **overall** North Star after the channel filter "
            "(benchmark vs each channel)."
        )

    tab_overview, tab_checks, tab_defs = st.tabs(["Overview", "Quality checks", "Definitions"])

    # --- Tab: single-action rates + volume (still ``df_sub`` universe) ---
    with tab_overview:
        st.subheader("Supporting adoption (same filtered universe)")
        s1, s2, s3 = st.columns(3)
        s1.metric("Adopted action 1", f"{df_sub['adopted_action_1'].mean():.1%}")
        s2.metric("Adopted action 3", f"{df_sub['adopted_action_3'].mean():.1%}")
        s3.metric("Churn proxy (cancel present)", f"{churn_rate:.1%}")
        st.caption(
            "These are **inputs** into the North Star story (coverage of each core action), "
            "not separate headline metrics."
        )

        st.subheader("Subscriber volume by channel (context only)")
        mix = (
            df_sub.groupby("channel", as_index=False)
            .agg(subscribers=("customerid", "count"))
            .sort_values("subscribers", ascending=True)
        )
        fig_vol = px.bar(
            mix,
            x="subscribers",
            y="channel",
            orientation="h",
            color_discrete_sequence=["#cbd5e1"],
            labels={"subscribers": "Subscribers", "channel": "Channel"},
        )
        fig_vol.update_layout(
            height=_chart_height_px(len(mix)),
            margin=dict(l=24, r=24, t=24, b=24),
            showlegend=False,
        )
        st.plotly_chart(fig_vol, use_container_width=True)
        st.caption("Use this only to understand **denominator scale** per channel.")

    # --- Tab: conditional North Star by churn proxy (N/A if split is empty) ---
    with tab_checks:
        st.subheader("North Star split by churn proxy (diagnostic)")
        n_not_churned = len(not_churned)
        n_churned = len(churned)
        cc1, cc2, cc3 = st.columns(3)
        if n_not_churned:
            cc1.metric(
                "North Star | not churned",
                f"{not_churned['north_star_both_core'].mean():.1%}",
            )
        else:
            cc1.metric(
                "North Star | not churned",
                "N/A",
                help="No subscribers without cancel_date in the current filter.",
            )
        if n_churned:
            cc2.metric(
                "North Star | churned",
                f"{churned['north_star_both_core'].mean():.1%}",
            )
        else:
            cc2.metric(
                "North Star | churned",
                "N/A",
                help="No subscribers with cancel_date in the current filter.",
            )
        cc3.metric("Churn proxy prevalence", f"{churn_rate:.1%}")
        st.caption(
            "This is a **sanity split**, not a causal claim. It helps detect weird channel mixes "
            "or structural selection issues."
        )

    # --- Tab: human-readable definitions (keep aligned with ``kpi_views.sql``) ---
    with tab_defs:
        st.markdown(
            "- **Subscriber:** `first_subscription_date` is present in `dim_customers_clean`\n"
            "- **DQ (in the view, not repeated here):** rows with "
            "`dq_subscription_before_signup` or `dq_cancel_before_subscription` are **dropped** "
            "in the view `WHERE` clause (same idea as `kpi_churn` / `kpi_feature_adoption`)\n"
            "- **Core actions:** `action_type_id` in `{1, 3}` (fixed in the view SQL)\n"
            "- **Adopted:** summed `total_usage` > 0 per action via `fct_usage_clean`\n"
            "- **North Star:** both core actions adopted (`north_star_both_core`)\n"
            "- **Churn proxy:** `cancel_date` present (`has_cancel_date`)\n"
            "\n**Limitation:** usage is aggregated without event timestamps — snapshot metric only.\n"
            f"\n**BigQuery object:** `{resolved_project}.{dataset}.{_VIEW_NAME}`"
        )

    # --- Debug / export aid: raw ids are already one row per subscriber in the view ---
    with st.expander("Preview filtered subscriber IDs (first 200)"):
        st.dataframe(df_sub[["customerid", "channel", "north_star_both_core"]].head(200))


if __name__ == "__main__":
    main()
