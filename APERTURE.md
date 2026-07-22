# Aperture — Quick Reference

Aperture is the **top bar above the chat**: a high-altitude, colored map of the
repo. Each tile is a file or directory; its **hue** comes from the active **Lens**.

- **Lens** = a way of coloring the repo (a set of up to 6 **Facets**).
- **Facet** = one category in a Lens (e.g. "UI", "networking"), each with a hue.
- Painting is async: colors fill in as the agent explores.

---

## Lenses

| Action | How |
| --- | --- |
| **Create / switch** by describing it | `/lens <what you want>` — agent proposes facets + palette, then paints |
| **Switch** (searchable picker) | `/lens-switch`, or click the **⌄** next to the Lens name |
| **Cycle** to next/prev Lens | click **◀ / ▶** (or the Lens name) in the legend |
| **Delete** the active Lens | click **✕** by the name → click again to confirm |

**Built-in Lenses** (always available):
`Architectural layer` (default) · `Changed since last commit` · `Edit recency` · `Bus factor`

**Drill-down Lenses (hierarchy).** A Lens can be *scoped to* one or more facets of
another Lens — ask for one with `/lens` while a Lens is active (e.g. "drill into the
UI facet").

**Painter context: `minimal` vs `medium`.** Each Lens picks how much per-file context
the painting agent sees. `minimal` (the default) sends the path, imports, and leading
comment — enough to place a file by what it *is*. `medium` adds a cheap structural
skeleton (exported names, file line count, and each top-level declaration's signature
+ length)

---

## Navigating the map

Top nav row (left → right):

| | Meaning |
| --- | --- |
| **⟳** | Refresh / repaint |
| **⌖** | Go to a path — type or paste a repo-relative path |
| **⌂** | Jump to repo root |
| **◀** | Up one level |
| **breadcrumb** | Click any crumb to jump to that level |

**On the tiles:**
- **Click a directory** → zoom into it.
- **Click a file** → *drill in*: the tile shows its **functions**, each colored by facet. Click again to undrill.
- **Hover** a tile → info + highlights its import neighbors.

---

## Tips

- Ask a question and the **build/plan agents may suggest a Lens** to match — just approve it.
- A pasted file path in **⌖** re-roots at its parent directory.
- Colors are semantic; structure (the tree) never reflows, so the map stays stable.
