import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch

fig, ax = plt.subplots(figsize=(22, 16))
ax.set_xlim(0, 22)
ax.set_ylim(0, 16)
ax.axis("off")
fig.patch.set_facecolor("#f0f4f8")

# ── Helpers ───────────────────────────────────────────────────────────────────

def cluster(ax, x, y, w, h, label, color, alpha=0.18, fontsize=9, labelcolor="#333"):
    rect = FancyBboxPatch((x, y), w, h,
                          boxstyle="round,pad=0.15",
                          linewidth=1.6, edgecolor=color,
                          facecolor=color, alpha=alpha, zorder=1)
    ax.add_patch(rect)
    ax.text(x + 0.2, y + h - 0.25, label,
            fontsize=fontsize, fontweight="bold",
            color=labelcolor, va="top", ha="left", zorder=2)

def node(ax, x, y, w, h, label, color, fontsize=8.5):
    rect = FancyBboxPatch((x, y), w, h,
                          boxstyle="round,pad=0.1",
                          linewidth=1.5, edgecolor=color,
                          facecolor="white", alpha=0.97, zorder=4)
    ax.add_patch(rect)
    ax.text(x + w / 2, y + h / 2, label,
            fontsize=fontsize, ha="center", va="center",
            color="#1a1a2e", zorder=5, multialignment="center",
            fontweight="semibold")

def arrow(ax, x1, y1, x2, y2, label="", color="#555"):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="-|>", color=color,
                                lw=1.4, connectionstyle="arc3,rad=0.0"),
                zorder=6)
    if label:
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        ax.text(mx, my + 0.13, label, fontsize=7, color=color,
                ha="center", va="bottom", style="italic", zorder=7,
                bbox=dict(facecolor="white", edgecolor="none", alpha=0.7, pad=1))

# ── Title ─────────────────────────────────────────────────────────────────────
ax.text(11, 15.55,
        "Agentic RAG on Kubeflow  —  Reference Architecture",
        fontsize=15, fontweight="bold", ha="center", va="center", color="#1a1a2e")

# ══════════════════════════════════════════════════════════════════════════════
# OCI outer border
cluster(ax, 0.3, 0.3, 21.4, 14.8,
        "Oracle Cloud Infrastructure  (Terraform-Provisioned)",
        "#e05c00", alpha=0.06, fontsize=10, labelcolor="#b84000")

# Kubeflow / OKE inner border
cluster(ax, 0.7, 0.6, 20.6, 13.6,
        "OKE  —  Kubeflow Cluster",
        "#1565c0", alpha=0.06, fontsize=9.5, labelcolor="#1565c0")

# ══════════════════════════════════════════════════════════════════════════════
# External Sources  (top-left)
cluster(ax, 0.9, 12.1, 4.3, 2.0, "External Sources", "#607d8b", alpha=0.14)
node(ax, 1.05, 12.4, 1.85, 1.2, "GitHub\nkubeflow/kubeflow\n(Docs + Issues)", "#24292e", 8)
node(ax, 3.1,  12.4, 1.85, 1.2, "Platform\nReference Arch\nDocs", "#607d8b", 8)

# ══════════════════════════════════════════════════════════════════════════════
# KFP Ingestion Pipeline  (top-center/right)
cluster(ax, 5.5, 11.4, 15.0, 2.8,
        "Ingestion Pipelines  (KFP v2)", "#2e7d32", alpha=0.12)

kfp_nodes = [
    (5.7,  11.7, "Scraper\nComponent"),
    (8.0,  11.7, "Cleaner &\nNormalizer"),
    (10.3, 11.7, "Chunker\nComponent"),
    (12.6, 11.7, "Embedder\nComponent"),
    (14.9, 11.7, "Indexer\nComponent"),
    (17.2, 11.7, "Validation\nComponent"),
]
for x, y, lbl in kfp_nodes:
    node(ax, x, y, 1.9, 1.05, lbl, "#2e7d32", 8)

for i in range(len(kfp_nodes) - 1):
    x1 = kfp_nodes[i][0] + 1.9
    x2 = kfp_nodes[i + 1][0]
    y  = kfp_nodes[i][1] + 0.52
    arrow(ax, x1, y, x2, y, color="#2e7d32")

# ══════════════════════════════════════════════════════════════════════════════
# Vector Store Indices
cluster(ax, 5.5, 8.8, 10.4, 2.2,
        "Vector Store Indices  (pgvector / Weaviate)", "#6a1b9a", alpha=0.12)
node(ax, 5.7,  9.05, 3.0, 1.4, "Docs\nIndex",              "#6a1b9a")
node(ax, 9.1,  9.05, 3.0, 1.4, "GitHub Issues\nIndex",     "#6a1b9a")
node(ax, 12.5, 9.05, 3.0, 1.4, "Platform Arch\nIndex",     "#6a1b9a")

# Indexer → indices
arrow(ax, 15.85, 11.7, 7.2,  10.45, "index", "#6a1b9a")
arrow(ax, 15.85, 11.7, 10.6, 10.45, "index", "#6a1b9a")
arrow(ax, 15.85, 11.7, 14.0, 10.45, "index", "#6a1b9a")

# ══════════════════════════════════════════════════════════════════════════════
# KServe LLM Serving  (right column)
cluster(ax, 16.5, 4.4, 4.6, 4.8,
        "LLM Serving  (KServe)", "#b71c1c", alpha=0.12)
node(ax, 16.7, 6.9, 4.1, 1.7, "Llama 3\nInferenceService\n[Scale-to-Zero]", "#b71c1c")
node(ax, 16.7, 4.7, 4.1, 1.7, "Embedding Model\nInferenceService",          "#e53935")

# Embedder component → Embedding model
arrow(ax, 14.85, 12.2, 18.7, 6.4, "embed calls", "#e53935")

# ══════════════════════════════════════════════════════════════════════════════
# API Layer  (left column, mid)
cluster(ax, 0.9, 5.4, 3.9, 3.0, "API Layer", "#0277bd", alpha=0.12)
node(ax, 1.1, 6.95, 3.3, 1.1, "Istio Ingress\n(future: MCP/security)", "#0277bd")
node(ax, 1.1, 5.7,  3.3, 1.1, "FastAPI / gRPC\nGateway",               "#0288d1")

# ══════════════════════════════════════════════════════════════════════════════
# Agentic Layer  (center)
cluster(ax, 5.0, 3.9, 11.0, 4.7,
        "Agentic Layer  (LangGraph / Kagent)", "#e65100", alpha=0.12)
node(ax, 7.4,  7.0,  3.0, 1.1, "Query Router\n+ Intent Classifier", "#e65100")
node(ax, 5.2,  5.3,  2.8, 1.3, "Docs\nAgent",          "#ef6c00")
node(ax, 8.5,  5.3,  2.8, 1.3, "Issues\nAgent",        "#ef6c00")
node(ax, 11.8, 5.3,  2.8, 1.3, "Platform Arch\nAgent", "#ef6c00")
node(ax, 8.4,  4.05, 3.0, 1.1, "Answer Synthesizer\n+ Citation Builder", "#e65100")

# ══════════════════════════════════════════════════════════════════════════════
# User  (bottom-left)
node(ax, 1.0, 2.4, 3.0, 1.3, "Developer / User", "#37474f")

# OCI Object Storage  (bottom-right)
node(ax, 17.5, 0.8, 3.2, 1.2, "OCI Object Storage\nPipeline Artifacts", "#e05c00")

# ══════════════════════════════════════════════════════════════════════════════
# Arrows — User <-> API
arrow(ax, 2.5, 3.7,  2.5, 5.7,  "question",     "#0277bd")
arrow(ax, 2.2, 5.7,  2.2, 3.7,  "cited answer", "#0277bd")
arrow(ax, 3.0, 6.25, 3.3, 6.95, "",             "#0277bd")   # gateway -> ingress
arrow(ax, 4.4, 6.25, 7.4, 7.3,  "",             "#e65100")   # gateway -> router

# Arrows — Router -> Agents
arrow(ax, 7.9,  7.0, 6.6,  6.6,  "",              "#ef6c00")
arrow(ax, 8.9,  7.0, 9.9,  6.6,  "",              "#ef6c00")
arrow(ax, 9.6,  7.0, 13.2, 6.6,  "",              "#ef6c00")
arrow(ax, 9.5,  7.2, 18.7, 7.75, "classify intent", "#b71c1c")

# Arrows — Agents -> Vector Indices
arrow(ax, 6.6,  8.8,  7.2,  10.05, "retrieve", "#6a1b9a")
arrow(ax, 9.9,  8.8,  10.6, 10.05, "retrieve", "#6a1b9a")
arrow(ax, 13.2, 8.8,  14.0, 10.05, "retrieve", "#6a1b9a")

# Arrows — Agents -> LLM (RAG prompts)
arrow(ax, 8.0,   5.9, 16.7, 7.6, "RAG prompt", "#b71c1c")
arrow(ax, 11.3,  5.9, 16.7, 7.8, "RAG prompt", "#b71c1c")
arrow(ax, 14.6,  5.9, 16.7, 8.0, "RAG prompt", "#b71c1c")

# Arrows — Agents -> Synthesizer
arrow(ax, 6.6,  5.3, 8.7,  5.15, "", "#e65100")
arrow(ax, 11.3, 5.3, 11.1, 5.15, "", "#e65100")

# Synthesizer -> LLM -> Gateway
arrow(ax, 11.4, 4.7,  16.7, 6.5,  "finalize + cite", "#b71c1c")
arrow(ax, 8.4,  4.05, 4.4,  6.25, "response",        "#0277bd")

# Arrows — External sources -> Scraper
arrow(ax, 2.9,  12.5, 5.7,  12.5, "scrape", "#2e7d32")
arrow(ax, 4.0,  12.8, 5.7,  12.8, "scrape", "#2e7d32")

# Scraper -> OCI storage
arrow(ax, 7.65, 11.7, 19.0, 2.0, "artifacts", "#e05c00")

# ══════════════════════════════════════════════════════════════════════════════
# Legend
legend_items = [
    ("#2e7d32", "KFP Ingestion Pipelines"),
    ("#6a1b9a", "Vector Store / Retrieval"),
    ("#e65100", "Agentic Layer (LangGraph/Kagent)"),
    ("#b71c1c", "LLM Serving (KServe)"),
    ("#0277bd", "API / Networking"),
    ("#e05c00", "OCI Infrastructure"),
]
for i, (color, label) in enumerate(legend_items):
    ax.add_patch(mpatches.Rectangle((0.5 + i * 3.6, 0.15), 0.38, 0.3,
                                    color=color, alpha=0.9, zorder=8))
    ax.text(1.0 + i * 3.6, 0.30, label,
            fontsize=8, va="center", color="#222", zorder=9)

plt.tight_layout(pad=0.4)
plt.savefig("kubeflow_agentic_rag.png", dpi=160, bbox_inches="tight",
            facecolor=fig.get_facecolor())
print("Saved: kubeflow_agentic_rag.png")
