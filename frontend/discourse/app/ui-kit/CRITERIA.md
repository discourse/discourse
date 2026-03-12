# UI Kit - Component Eligibility Criteria

Components are eligible for inclusion in `ui-kit` if they meet these criteria:

## 1. Multi-use
Component is used in 2+ unrelated features/areas of the app.

## 2. No newer counterpart
Component isn't superseded by float-kit, form-kit, or select-kit. If form-kit/float-kit imports the component, it qualifies (it's a primitive they build on).

## 3. Child exception
Single-use child components travel with their parent (organized in parent-named folders).

## 4. General purpose
Serves a reusable UI purpose, not tied exclusively to one domain feature. Discourse-specific is fine as long as it's used as a building block across multiple areas.
