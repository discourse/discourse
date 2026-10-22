# Tag reads on JsonApiKit: spike findings

Branch `tag-search-json-api-spike`, off `main` at `24009eb109b`. Exploratory, not meant to merge. No upstream commit since then touches `lib/json_api_kit` or tag search.

## What the spike shows

The tag pickers' reads can move from `/tags/filter/search` to JsonApiKit with two endpoints:

- `GET /api/tags`: browse the tags the user can see. Filters: `id`, `name` (exact, case-insensitive), `term` (contains, including localized names), `exclude`, `excludeSynonyms`, `excludeHasSynonyms`, `recentlyUsed`, `category`. Sorts: `name`, `publicTopicCount`, `staffTopicCount` (staff only). Cursor paging.
- `GET /api/tags/applicable`: the tags the user may apply to a topic. Inputs `category` and `held` (the tags the topic already has), plus `term`, `name` and the synonym filters. The eligibility rules of `DiscourseTagging.filter_allowed_tags(for_input: true)` apply to every request; no parameter turns them off.

`spec/resources/tag_resource_spec.rb` compares the applicable endpoint with `filter_allowed_tags(for_input: true)` over every combination of:

- anonymous, user, moderator and admin;
- six categories: none, open, restricted to tags and a group, restricted with global tags allowed, one required group, two required groups whose order matters;
- five sets of held tags;
- four terms.

It also compares the `category` filter with `filter_allowed_tags` outside input. Both agree.

## What the framework needed

All in `lib/json_api_kit`, each with specs that were seen failing first and planted defects that were caught.

1. **Context-aware filters.**
   - A filter block that declares a third parameter receives `Filter::Context` (guardian, edition, every filter value).
   - The block's arity selects the signature, as `Readable.for` does, so two-parameter filters are unchanged.
   - The tag browse filters need it for the guardian (`category`, `recentlyUsed`).
2. **Readable sorts.**
   - `sort :staff_topic_count, readable: ->(guardian) { ... }`. A guardian the rule refuses gets "No such sort".
   - **Security gap, present on `main` too:** a cursor carries the raw sort values, so a sort on a column hidden by an attribute's `readable:` leaks it. An anonymous probe with an unrestricted staff-count sort got the cursor `["2e045692",0,41,2777]`, and 41 was the hidden count.
   - No resource on `main` sorts on a hidden column today (checked: `GroupResource`, `UserResource`, the data explorer's `QueryResource`), so nothing leaks yet.
   - The tag resource keeps today's staff ordering: the attribute and the sort share one rule mirroring `Tag.topic_count_column`, so only viewers who already see the count can sort by it.
3. **Filter defaults and duplicate names.**
   - `filter :x, default: value` runs with its default when the request leaves it out, and other filters see that default.
   - A second declaration of the same filter name now raises. It used to replace the first silently.
4. **Named collections.**
   - `collection :applicable do ... end` declares another list endpoint over the same records, with the same type, scope, fields, sorts and paging, but its own filters.
   - Version changes reach those filters through `collection` inside `resource`. Filter names carry the collection, so the resource's browse filters keep their own history.
   - Without this, two resources sharing `type :tags` share every version change: removing an input from one would rebind the other's filter of the same name for older pins.
5. **Input scopes and scope filters.**
   - `input_scope do |rows, guardian, category:, held:, term: nil| ... end` runs on every request: after the guardian scope (still the visibility boundary, never versioned) and before ordinary filters.
   - `scope_filter :category, default: nil` declares an input that the input scope reads and that never filters on its own. The default is required, because an omitted input still means something ("a topic without a category").
   - The framework combines the block's result with the visible rows using `and`, not `merge`. `merge` replaces a condition on a column the block also constrains, which a planted defect showed lets rows outside visibility through.
   - Controllers check, when they declare the resource, that every keyword names a filter and every required keyword has a default.
6. **Versioned input scopes.**
   - `changed_input_scope { ... }` retains the input scope a listing used before a version, and `removed_scope_filter :x, default:` retains an input it read.
   - A request pinned before a change runs the oldest retained input scope after its pin, inside today's visibility.
   - Its keywords bind the way the glossary binds the request's filter names: the oldest removal after the pin, else the current filter.
   - A current filter that reuses a removed name lends no default to the older pins.
   - `spec/integration/json_api_kit/every_edition_spec.rb` checks every shipped resource and collection at every version.

## Queries

A user's request to the applicable endpoint, with a fresh guardian as each request builds:

| Case | `filter_allowed_tags` | Applicable endpoint | Full `Tags::Search` |
|---|---|---|---|
| No category | 4 | 3 | 4 |
| A restricted category | 6 | 4 | 29 (with a term) |
| A category with a required group | 6 | 4 | 9 |

The full search also computes the disabled-tag and forbidden-tag explanations, which the spike leaves out. An earlier shape of the endpoint picked a quadratic plan when the tables had no statistics (284 ms for opening the picker). After resolving the category in one query and moving the group ids into a subquery, the plan stays linear with or without statistics: about 20 ms on 5,000 tags.

## Decisions to confirm

- **The admin required-group rule.** Today admins are narrowed to a required group only when there is no term and the group has at least as many tags as the picker asks for (`lib/discourse_tagging.rb:647-661`, from #13242). Cursor paging has no page limit to compare against, so the spike narrows admins whenever there is no term (option B). The alternative is never narrowing admins (option A): it matches the 2019 intent and the save-time exemption (`validate_required_tags_from_group` skips admins).
- **Invisible categories** read as "no category", as `Tags::Search#fetch_category` does today. Endpoint policy, not framework behaviour.
- **Recency order.** `filter[recentlyUsed]` keeps the set of recent tags but not their order; only a sort that depends on the request would keep it.

## Smaller findings

- **No viewer-dependent attributes.** Attribute values receive only the record, so the viewer-dependent `pm_only` of today's search (`app/controllers/tags_controller.rb:627`) is left out.
- **Unrouted relationship links.** Relationships render only on `include`, and then link to `/api/tags/:id/target-tag`, which nothing routes. The data explorer has the same gap.
- **Removed filters under internal names.** Through `Filter::Context`, a removed filter appears as `__removed_filter_<id>`. Input scopes avoid this through their bindings; plain contextual filters still see internal names.
- **The search term isn't cleaned.** The service cleans it with `DiscourseTagging.clean_tag`; the spike's `term` filter doesn't.
- **The contract spec passed a class.** `spec/lib/json_api_kit/request/contract/collection_spec.rb` now passes a resource instance, as production does. Readable sorts need the guardian, and a class fallback would allow every sort.

## Open questions for the framework

- **Naming:** `collection`, `scope_filter`, `input_scope`, `changed_input_scope`, `removed_scope_filter`.
- **Typed values:** inputs are still checked only for shape (scalar or flat list), so input scopes cast values themselves.
- **Translating values across versions:** renames change keys only, so a change in an input's meaning needs `removed_scope_filter` plus `changed_input_scope`.
- **Single-record endpoints:** `member` is the natural name; collections have no `show` route.
