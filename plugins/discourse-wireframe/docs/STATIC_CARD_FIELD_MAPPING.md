# Static Card: superseded transition proposal

The current schema, delivery sequence and verification gates are in
[Static Card implementation plan](STATIC_CARD_EDITOR_PLAN.md).

On 2026-09-09 the user confirmed the existing blocks are pre-release and backward
compatibility is not required. The former additive mapping, conversion classifier,
legacy renderer retention and per-instance conversion blockers are withdrawn.
Do not implement them.

The approved leaf editing model and visual study remain the target. The current
plan replaces the API directly, removes duplicate static-card types and updates
repository-owned examples/tests. It does not authorize rewriting live site data
or deleting uploads.
