# AI Agent Migration Notes

This plugin now treats `agent` as the only canonical runtime/admin/API term.

## Decisions

- File paths, classes, routes, serializers, services, eval helpers, and specs use `agent` naming.
- There is no runtime legacy terminology shim. Existing code should use the `agent` routes, payload roots, and constants directly.
- The database remains centered on the existing `ai_agents` schema and `ai_agent_id` references.
- `allow_personal_messages` remains the PM-specific flag. The migration does not rename unrelated `personal` terminology to `agent`.

## Cleanup expectations

- New code should not introduce legacy agent aliases, payload roots, or file paths.
- Admin/API responses should expose only `ai_agent` / `ai_agents`.
- If compatibility is required later, keep it isolated to one removable boundary instead of duplicating controller/model behavior.
