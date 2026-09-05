/* eslint-disable no-undef, no-unused-vars */
// Scan-mode replacements for the Ruby helper methods PrettyText attaches as
// `__Ruby.*`. The pretty-text bundle captures `globalThis.__Ruby` when it is
// evaluated, so this must run first. Render-oriented lookups are inert; the
// hashtag lookup — which decides whether a `#slug` produces a token at all —
// answers from source-site data injected as `__scanConfig`.

__Ruby = {
  // The key is deterministic and never reaches the token data.
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
    // The counterpart of Ruby's NameNormalizer, which the injected name sets
    // went through: NFC, downcase, and both lowercase sigmas as one (see that
    // module for why the sigma matters).
    const ref = slug.normalize("NFC").toLowerCase().replace(/\u03c2/g, "\u03c3");
    // `#slug::type` forces one type; `#parent:child` addresses a category by
    // its child slug; `ref` keeps the typed form, like the host lookup service.
    // Only slug, type and ref shape the tokens a scan reads.
    const [name, forcedType] = ref.split("::");
    const types = forcedType ? [forcedType] : typesInPriorityOrder;

    for (const type of types) {
      if (type === "category") {
        // Ruby's split(":") drops trailing empty segments, so core resolves a
        // dangling `#general:` to the `general` category; JS split keeps the
        // empty tail, hence the filter.
        const slugPart = name.split(":").filter((part) => part !== "").pop() || "";
        if (slugPart !== "" && __scanConfig.categorySlugs[slugPart]) {
          // `text` becomes the rendered label, which no scan reads.
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
