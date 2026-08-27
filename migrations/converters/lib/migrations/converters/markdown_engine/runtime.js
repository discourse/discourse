/* eslint-disable no-undef, no-unused-vars */
// Scan-mode replacements for the Ruby helper methods PrettyText attaches as
// `__Ruby.*`. The pretty-text bundle captures `globalThis.__Ruby` when it is
// evaluated, so this must run first. Render-oriented lookups are inert; the
// hashtag lookup — which decides whether a `#slug` produces a token at all —
// answers from source-site data injected as `__scanConfig`.

__Ruby = {
  // The processor's i18n shim routes translations here; the key is
  // deterministic and never reaches the token data the scan extracts.
  t(key) {
    return key;
  },
  avatar_template() {
    return "";
  },
  lookup_primary_user_group() {
    return null;
  },
  format_username(username) {
    return username;
  },
  // Leaving every short URL unresolved makes the upload protocol store the
  // original in data-orig-*, which is the value the scan extracts.
  lookup_upload_urls() {
    return {};
  },
  get_topic_info() {
    return null;
  },
  get_current_user() {
    return null;
  },
  hashtag_lookup(slug, cookingUserId, typesInPriorityOrder) {
    // The counterpart of Ruby's NameNormalizer (Unicode NFC, then downcase):
    // the injected name sets are normalized that way, so the sought slug must
    // be too, or a decomposed spelling in a post misses the composed name.
    const ref = slug.normalize("NFC").toLowerCase();
    // `#slug::type` forces one type; `#parent:child` addresses a category by
    // its child slug; `ref` preserves the typed form including a `::type`
    // suffix, like the host lookup service. This mirrors that service far
    // enough for scanning, where only slug, type, and ref shape the tokens.
    const [name, forcedType] = ref.split("::");
    const types = forcedType ? [forcedType] : typesInPriorityOrder;

    for (const type of types) {
      if (type === "category") {
        // Ruby's split(":") drops trailing empty segments, so core resolves a
        // dangling `#general:` to the `general` category; JS split keeps the
        // empty tail, hence the filter.
        const slugPart = name.split(":").filter((part) => part !== "").pop() || "";
        if (slugPart !== "" && __scanConfig.categorySlugs[slugPart]) {
          // `text` becomes the rendered label; the scan reads slug and type,
          // so the slug is label enough.
          return {
            relative_url: "/c/" + slugPart,
            text: slugPart,
            type: "category",
            slug: slugPart,
            id: 0,
            ref,
          };
        }
      } else if (type === "tag") {
        if (__scanConfig.tagNames[name]) {
          return {
            relative_url: "/tag/" + name,
            text: name,
            type: "tag",
            slug: name,
            id: 0,
            ref,
          };
        }
      }
    }
    return null;
  },
};
