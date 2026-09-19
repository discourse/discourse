# Conversion-completeness checklist

Treat a rename as inventory movement, not completed conversion. A `.js`/`.gjs` file renamed
to `.ts`/`.gts` remains pending until its implementation satisfies every applicable item
below. Do not mark a file, service group, or plan phase complete from extension counts or a
subset of checks.

## Per-file acceptance

1. Type every injected service with its canonical class. A typed injection is still
   insufficient when a called dependency method has untyped parameters or an `any` return;
   type the dependency's relevant public method instead of allowing an unchecked value
   across the boundary. Suffix the imported service class binding with `Service`; leave the
   injection property and module path unchanged.
2. Type public fields, method parameters, and returns precisely. Type private state where
   inference would be null-only, empty-collection-only, or otherwise misleading. Do not rely
   on the loose repository tsconfig to accept implicit `any`.
3. Add useful TSDoc to the typed public API: exported type fields, service
   fields/methods/parameters, and every component `Signature` arg, block, nested arg field,
   and yielded tuple value.
4. Remove redundant legacy `@param {Type}`, `@returns {Type}`, `@type`, and `@property
   {Type}` tags. Preserve useful prose as untyped TSDoc tags.
5. Search for bare `@service`, explicit or implicit `any`, suppression directives, stale
   typed JSDoc, and undocumented casts. Passing `ember-tsc` does not prove these are absent
   under the loose global configuration.
6. Inspect each core dependency before defining a local type. Prefer the canonical type,
   including one inferred from unconverted JavaScript. If a verified runtime field is
   missing, use the narrowest extension and a `TODO(typescript-pending)` naming the gap and
   the removal condition.
7. Treat transport, JSON, browser-storage, DOM, and untyped-component casts as explicit
   boundaries. Keep each cast narrow and tag temporary typing gaps with
   `TODO(typescript-pending)`. Never add validation or narrowing that changes behavior (see
   the faithfulness trap in `js-to-ts-conversion.md`).
8. Keep small one-use object shapes inline. Name a shape only when the name adds reuse,
   navigation, or architectural meaning; do not manufacture interfaces merely to make a file
   look typed.
9. Run `bin/lint --fix` and re-read the file after formatting and member ordering.
   Converting previously unchecked JavaScript can expose lint failures in untouched-looking
   code; those failures belong to the conversion.
10. Audit explicit `.js`/`.gjs` imports after each rename and run the relevant runtime tests.
    Tests may remain JavaScript when their conversion is out of scope, but their imports and
    runtime coverage must still work.

## Incremental evidence versus completion

- During a large migration, filter type-check output by the files under audit so unrelated
  pending files do not hide regressions. This proves only that the named files have no
  reported errors.
- Keep renamed-but-unaudited files and partially typed dependency chains marked pending. A
  consumer is not strict-grade while a dependency method it calls still leaks `any`.
- Do not count a subsystem complete until every file in its planned inventory satisfies the
  per-file checklist.
- Final acceptance still requires clean full lint and type-check, stale-import and
  suppression audits, and relevant runtime tests. Targeted green checks never substitute for
  these full gates.
