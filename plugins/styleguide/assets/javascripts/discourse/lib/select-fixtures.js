import { i18n } from "discourse-i18n";

/**
 * Fixtures for the `DSelect` styleguide page.
 *
 * The page is the only surface rendering `DSelect`, so its data is what a reader judges the
 * component by. Placeholder content ("Orange", "Option 1…5000") makes even a correct component
 * look unfinished, so the sets below are shaped to be worth reading.
 *
 * The set is built to span the dimensions the component actually stresses, not to be large:
 * label lengths from three characters to ninety, three writing systems and two RTL scripts,
 * optional fields present on some rows and absent on others, item states (disabled, action row,
 * unresolvable, restricted), set sizes of 4 / ~12 / ~15 / 5000, uneven group sizes, and counts
 * spanning single digits to five so a trailing column has visibly different widths.
 *
 * Anything needing translation or a store is exported as a *function*, not a constant: a
 * module-scope `i18n()` would run at import time, before locales are guaranteed to be loaded.
 *
 * LOAD-BEARING CONSTRAINTS. System specs read these exact shapes, and most break SILENTLY — the
 * assertion still passes while its intent has moved — so each one names the spec that depends
 * on it. Every constraint below is live; do not add one here that nothing consumes.
 *
 *   LOCALES.length >= 15            large enough to scroll a panel; the default set everywhere
 *                                   an example's subject is a mechanism rather than markup
 *   FOUR_OPTIONS.length === 4       d_select_no_probe_spec: `count: 4` and aria-setsize "4"
 *   FOUR_OPTIONS[0..2] labels       d_select_multi_chip_roving_spec: three chips added in order,
 *                                   then asserted by label and by DOM order
 *   ASYNC_BUTTON_DELAY === 1200     d_select_no_probe_spec: its `wait: 10` and `sleep 4` budget
 *   TOPIC_COUNT === 5000            d_select_bounded_reveal_spec: aria-setsize "5000", and
 *                                   reveal_to_index(4999) must reach exactly 4999
 *   "#4242" ends exactly one topic  d_select_cursor_source_spec: filtering must narrow to a
 *                                   single row. Any second occurrence breaks `count: 1`
 *   PAGE_SIZE === 50 over 5000      d_select_cursor_source_spec: the first response must be
 *                                   incomplete, so the source reports setsize -1 while paging
 *   MAXIMUM === 3, seeded at cap    smoke_test_spec: renders .d-combobox__limit plus a
 *                                   disabled option
 *   REVIEWER_IDS.length === 7       d_select_showcases_spec: exactly 7 resolved chips, and
 *                                   seven is what makes them wrap in a 28rem control
 *   REVIEWER_IDS includes 999       d_select_showcases_spec: unresolvable -> "deleted-user"
 *   PEOPLE has username "maya"      d_select_showcases_spec: chip label assertion
 *   Taylor Kim is disabled AND      d_select_showcases_spec: asserts a disabled option exists
 *   not pre-selected
 *   TAGS excludes "architecture"    d_select_showcases_spec: the create-a-tag flow needs it to
 *                                   be genuinely absent
 *   TEAM_MEMBERS spans >= 2 teams   smoke_test_spec: `.d-combobox__group-header` minimum: 2
 */

/** Rejects when `signal` aborts, otherwise resolves after `ms`. */
export function delay(signal, ms = 750) {
  return new Promise((resolve, reject) => {
    // `signal` is optional on purpose: the engine's resolve path may call a source without one
    // (`resolveSelection` defaults its options to `{}`), and a TypeError there is swallowed into
    // a silent "unresolved" row rather than surfacing.
    if (signal?.aborted) {
      return reject(signal.reason ?? new Error("Aborted"));
    }

    const timer = setTimeout(resolve, ms);

    signal?.addEventListener(
      "abort",
      () => {
        clearTimeout(timer);
        reject(signal.reason ?? new Error("Aborted"));
      },
      { once: true }
    );
  });
}

export const ASYNC_BUTTON_DELAY = 1200;
export const MAXIMUM = 3;
export const PAGE_SIZE = 50;
export const TOPIC_COUNT = 5000;

/* Interface languages — the default set for any example whose subject is a mechanism rather
   than markup. Endonyms are literals, not display strings, so they are not translated, and they
   carry three writing systems and two RTL scripts. That makes RTL and non-Latin the page's
   ordinary content instead of a quarantined "hostile input" demo. */
export const LOCALES = [
  { id: "en", name: "English (US)" },
  { id: "es", name: "Español" },
  { id: "pt-BR", name: "Português (Brasil)" },
  { id: "fr", name: "Français" },
  { id: "de", name: "Deutsch" },
  { id: "it", name: "Italiano" },
  { id: "nl", name: "Nederlands" },
  { id: "pl", name: "Polski" },
  { id: "tr", name: "Türkçe" },
  { id: "ru", name: "Русский" },
  { id: "ja", name: "日本語" },
  { id: "ko", name: "한국어" },
  { id: "zh-CN", name: "简体中文" },
  { id: "ar", name: "العربية" },
  { id: "he", name: "עברית" },
];

/**
 * The four-row subset the silent-source spec counts. Order matters: the first three are the
 * labels the chip-roving spec adds and then asserts by DOM order.
 *
 * Hand-picked rather than `LOCALES.slice(0, 4)`, because the chip-roving spec *types* these
 * labels through the typeahead. The first four locales include parentheses and non-ASCII
 * ("Português (Brasil)", "Español"), which makes a `send_keys` round-trip a flake waiting to
 * happen. These four are plain ASCII with distinct first letters, so a filter narrows to one row
 * on the first keystroke.
 */
export const FOUR_OPTIONS = [
  LOCALES.find((locale) => locale.id === "de"),
  LOCALES.find((locale) => locale.id === "it"),
  LOCALES.find((locale) => locale.id === "nl"),
  LOCALES.find((locale) => locale.id === "pl"),
];

/* People. Avatars are local SVGs rather than the shared `/images/avatar.png`, because twelve
   identical grey circles was the single most damaging thing on the old page, and letter avatars
   are not an option (the avatar proxy is disabled under `Rails.env.test?`, so every screenshot
   would capture blanks).

   Optional fields are deliberately uneven — a couple carry a status, one carries no title at
   all, one name is long enough to wrap. A set where every row has every field is the tell of a
   mock; real member lists are ragged. */
const AVATAR = (name) => `/plugins/styleguide/images/avatars/${name}.svg`;

export const PEOPLE = [
  {
    id: 101,
    username: "maya",
    name: "Maya Alvarez",
    title: "Design lead",
    avatar: AVATAR("aurora"),
  },
  {
    id: 102,
    username: "devon",
    name: "Devon Park",
    title: "Frontend",
    avatar: AVATAR("cobalt"),
  },
  {
    id: 103,
    username: "ines",
    name: "Inés Rojas",
    title: "Accessibility",
    avatar: AVATAR("moss"),
    status: "On leave until Friday",
  },
  {
    id: 104,
    username: "kwame",
    name: "Kwame Boateng",
    title: "Security",
    avatar: AVATAR("ember"),
  },
  {
    id: 105,
    username: "sora",
    name: "Sora Tanaka",
    title: "Performance",
    avatar: AVATAR("indigo"),
  },
  {
    id: 106,
    username: "noor",
    name: "Noor Haddad",
    title: "Documentation",
    avatar: AVATAR("saffron"),
  },
  {
    id: 107,
    username: "taylor",
    name: "Taylor Kim",
    title: "Support",
    avatar: AVATAR("slate"),
    // Not pre-selected, and disabled: the showcases spec asserts a disabled option renders.
    disabled: true,
  },
  {
    id: 108,
    username: "lucia",
    name: "Lucía Ferrer",
    title: "Community",
    avatar: AVATAR("rose"),
  },
  // The long-name row. Nothing else on the page forces a two-line name to wrap inside a row or
  // truncate inside a chip.
  {
    id: 109,
    username: "annelies",
    name: "Annelies van der Meer-Okonkwo",
    title: "Internationalisation",
    avatar: AVATAR("teal"),
    status: "Reviewing translations",
  },
  {
    id: 110,
    username: "rafa",
    name: "Rafa Ortiz",
    avatar: AVATAR("plum"),
  },
  {
    id: 111,
    username: "wei",
    name: "Wei Zhang",
    title: "Infrastructure",
    avatar: AVATAR("sand"),
  },
  {
    id: 112,
    username: "amara",
    name: "Amara Nwosu",
    title: "Trust and safety",
    avatar: AVATAR("forest"),
    status: "Back Monday",
  },
];

/** Seven seeded reviewer ids, one of which (999) resolves to nothing so the unresolved fallback
 *  is exercised. Seven is also what makes the chips wrap in a 28rem control. */
export const REVIEWER_IDS = [101, 102, 103, 104, 105, 106, 999];

/* Deliberately uneven: four, three and one. Equal groups make a header look decorative, because
   a reader cannot tell the grouping from the ordering. Taylor is the sole support member and is
   disabled, so the smallest group is also the one that proves a disabled row still renders
   under a header. */
export const TEAM_MEMBERS = [
  { ...PEOPLE[0], team: "design" },
  { ...PEOPLE[7], team: "design" },
  { ...PEOPLE[8], team: "design" },
  { ...PEOPLE[11], team: "design" },
  { ...PEOPLE[1], team: "engineering" },
  { ...PEOPLE[4], team: "engineering" },
  { ...PEOPLE[10], team: "engineering" },
  { ...PEOPLE[6], team: "support" },
];

/** Team labels, translated. A function rather than a constant so `i18n` runs at render.
 *  Keyed under the section rather than under a group, because more than one group renders it. */
export function teamLabels() {
  return {
    design: i18n("styleguide.sections.select.teams.design"),
    engineering: i18n("styleguide.sections.select.teams.engineering"),
    support: i18n("styleguide.sections.select.teams.support"),
  };
}

/* Tags. Counts run from five digits to one so a trailing count column has visibly different
   widths rather than four rows of the same number, and one slug is long enough to truncate.
   Deliberately excludes "architecture" — the create-a-tag flow creates exactly that. */
export const TAGS = [
  { slug: "design-system", label: "design-system", count: 12483 },
  { slug: "accessibility", label: "accessibility", count: 3094 },
  { slug: "performance", label: "performance", count: 871 },
  { slug: "onboarding", label: "onboarding", count: 455 },
  { slug: "theming", label: "theming", count: 242 },
  { slug: "migrations", label: "migrations", count: 130 },
  { slug: "release-notes", label: "release-notes", count: 76 },
  { slug: "localization", label: "localization", count: 41 },
  { slug: "self-hosted", label: "self-hosted", count: 28 },
  { slug: "plugin-development", label: "plugin-development", count: 17 },
  {
    slug: "backwards-compatibility-policy",
    label: "backwards-compatibility-policy",
    count: 9,
  },
  { slug: "rfc", label: "rfc", count: 3 },
];

/* Discourse's default category palette, so the page reads as one forum rather than a swatch
   test. The same colours back the topic bullets below. */
const CATEGORY_PALETTE = {
  blue: "0088CC",
  grey: "808281",
  orange: "E45735",
  green: "9EB83B",
  red: "BF1E2E",
  teal: "12A89D",
};

/**
 * Categories, as real `Category` records so the badge renderer behaves exactly as it does in
 * the app. Needs a store, so this is a function.
 *
 * Fabricated rather than read from `site.categories`: the test database seeds only
 * "Uncategorized", and `Fabricate(:category)` skips the definition topic, so real records would
 * leave the demo empty in CI and in every screenshot.
 */
export function categories(store) {
  return [
    {
      id: 1201,
      name: "Feature requests",
      slug: "feature-requests",
      color: CATEGORY_PALETTE.blue,
      description_excerpt:
        "Ideas for what Discourse should do next, and discussion of the trade-offs.",
      topic_count: 12483,
    },
    {
      id: 1202,
      name: "Support",
      slug: "support",
      color: CATEGORY_PALETTE.orange,
      description_excerpt:
        "Something is broken and you would like help working out why.",
      topic_count: 3094,
    },
    {
      id: 1203,
      name: "Documentation",
      slug: "documentation",
      color: CATEGORY_PALETTE.grey,
      description_excerpt: "Guides, references, and how-to articles.",
      topic_count: 455,
    },
    {
      id: 1204,
      name: "Plugin development",
      slug: "plugin-development",
      color: CATEGORY_PALETTE.green,
      // No excerpt: a category without a description is ordinary, and the row has to survive it
      // without collapsing.
      topic_count: 130,
    },
    {
      id: 1205,
      name: "Staff",
      slug: "staff",
      color: CATEGORY_PALETTE.red,
      description_excerpt: "Private category for site staff.",
      topic_count: 41,
      read_restricted: true,
    },
  ].map((attrs) => store.createRecord("category", attrs));
}

/* Colour schemes. The swatch strip is the clearest case on the page of a block expressing
   something no argument could: the value is a colour, and only markup can show it. */
export const COLOR_SCHEMES = [
  { id: "light", name: "Light", colors: ["FFFFFF", "222222", "0088CC"] },
  { id: "dark", name: "Dark", colors: ["1E1E1E", "E8E8E8", "0F82AF"] },
  { id: "neutral", name: "Neutral", colors: ["FFFFFF", "2B2B2B", "51839B"] },
  {
    id: "grey-amber",
    name: "Grey amber",
    colors: ["1D1D1D", "E5E5E5", "F0B849"],
  },
  { id: "latte", name: "Latte", colors: ["FDF6E3", "3B3228", "B58900"] },
  { id: "summer", name: "Summer", colors: ["FFFAF0", "4D4D4D", "FF7F50"] },
  {
    id: "dark-rose",
    name: "Dark rose",
    colors: ["2B1B23", "F2E0E6", "C76B8E"],
  },
  { id: "wcag", name: "WCAG", colors: ["FFFFFF", "000000", "0033CC"] },
];

/* Emoji. Grouped, because an emoji picker without groups is a wall, and the shortcode is what a
   reader actually types — so it belongs in the row, in monospace, beside the glyph. */
export const EMOJI = [
  { id: "tada", name: "tada", group: "Celebration" },
  { id: "rocket", name: "rocket", group: "Celebration" },
  { id: "sparkles", name: "sparkles", group: "Celebration" },
  { id: "heart", name: "heart", group: "Celebration" },
  { id: "bug", name: "bug", group: "Development" },
  { id: "wrench", name: "wrench", group: "Development" },
  { id: "hammer", name: "hammer", group: "Development" },
  { id: "bulb", name: "bulb", group: "Development" },
  { id: "books", name: "books", group: "Writing" },
  { id: "memo", name: "memo", group: "Writing" },
  { id: "mag", name: "mag", group: "Writing" },
  { id: "lock", name: "lock", group: "Moderation" },
  { id: "warning", name: "warning", group: "Moderation" },
  { id: "eyes", name: "eyes", group: "Moderation" },
];

/* User groups. The trailing element here is a pill rather than a number, which is a different
   shape from the tag and topic rows and the one most admin pickers need. */
export const USER_GROUPS = [
  {
    id: 1,
    name: "admins",
    fullName: "Admins",
    icon: "shield-halved",
    memberCount: 4,
    automatic: true,
  },
  {
    id: 2,
    name: "moderators",
    fullName: "Moderators",
    icon: "shield-halved",
    memberCount: 11,
    automatic: true,
  },
  {
    id: 3,
    name: "staff",
    fullName: "Staff",
    icon: "users",
    memberCount: 15,
    automatic: true,
  },
  {
    id: 11,
    name: "design_system",
    fullName: "Design system",
    icon: "palette",
    memberCount: 9,
  },
  {
    id: 12,
    name: "translators",
    fullName: "Translators",
    icon: "language",
    memberCount: 63,
  },
  {
    id: 13,
    name: "beta_testers",
    fullName: "Beta testers",
    icon: "flask",
    memberCount: 428,
  },
  {
    id: 14,
    name: "plugin_authors",
    fullName: "Plugin authors",
    icon: "puzzle-piece",
    memberCount: 137,
  },
];

/* Badges. `dIconOrImage` takes one of these directly and renders `<img alt="">` or an icon, so
   the row needs no image handling of its own. Rarity drives the colour, exactly as the badge
   pages do. */
export const BADGES = [
  {
    id: 1,
    name: "Welcome",
    icon: "heart",
    rarity: "bronze",
    grantCount: 41208,
  },
  {
    id: 2,
    name: "Nice post",
    icon: "star",
    rarity: "bronze",
    grantCount: 8834,
  },
  {
    id: 3,
    name: "Good post",
    icon: "star",
    rarity: "silver",
    grantCount: 1206,
  },
  { id: 4, name: "Great post", icon: "star", rarity: "gold", grantCount: 94 },
  { id: 5, name: "Editor", icon: "pencil", rarity: "bronze", grantCount: 6521 },
  {
    id: 6,
    name: "Autobiographer",
    icon: "user",
    rarity: "bronze",
    grantCount: 3390,
  },
  {
    id: 7,
    name: "Anniversary",
    icon: "cake-candles",
    rarity: "silver",
    grantCount: 712,
  },
  {
    id: 8,
    name: "Leader",
    icon: "certificate",
    rarity: "gold",
    grantCount: 23,
  },
];

/* Timezones. The point of this set is the one thing no other fixture can show: a row whose
   most useful content is not stored on the item at all. */
export const TIMEZONES = [
  { id: "Pacific/Auckland", name: "Auckland" },
  { id: "Asia/Tokyo", name: "Tokyo" },
  { id: "Asia/Kolkata", name: "Kolkata" },
  { id: "Europe/Istanbul", name: "Istanbul" },
  { id: "Europe/Berlin", name: "Berlin" },
  { id: "Europe/London", name: "London" },
  { id: "Atlantic/Reykjavik", name: "Reykjavík" },
  { id: "America/Sao_Paulo", name: "São Paulo" },
  { id: "America/New_York", name: "New York" },
  { id: "America/Chicago", name: "Chicago" },
  { id: "America/Los_Angeles", name: "Los Angeles" },
  { id: "Pacific/Honolulu", name: "Honolulu" },
];

/**
 * The current wall-clock time in a zone, formatted for the reader's locale.
 *
 * Used as a template helper so it is evaluated while the row renders. Plain `Intl` rather than a
 * date library: the zone conversion is the only thing needed and it is native.
 *
 * @param {string} timeZone - an IANA zone id.
 * @returns {string} e.g. "09:41"
 */
export function localTimeIn(timeZone) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    timeZone,
  }).format(new Date());
}

/**
 * Notification levels, translated, with one disabled row and one action row.
 *
 * A function rather than a constant because the titles and descriptions are translated.
 *
 * @param {Function} [onManage] - invoked by the action row, which selects nothing.
 */
export function notificationLevels(onManage) {
  // Keyed under the section, not a group: the hero, the icon-only example and the notification
  // picker all render these, so they are data rather than one card's copy.
  const t = (key) =>
    i18n(`styleguide.sections.select.notification_levels.${key}`);

  return [
    {
      level: "muted",
      icon: "bell-slash",
      title: t("muted"),
      description: t("muted_description"),
    },
    {
      level: "normal",
      icon: "bell",
      title: t("normal"),
      description: t("normal_description"),
    },
    {
      level: "tracking",
      icon: "circle-dot",
      title: t("tracking"),
      description: t("tracking_description"),
    },
    {
      level: "watching",
      icon: "eye",
      title: t("watching"),
      description: t("watching_description"),
    },
    {
      level: "mentions",
      icon: "at",
      title: t("mentions"),
      description: t("mentions_description"),
      disabled: true,
    },
    {
      level: "manage",
      icon: "gear",
      title: t("manage"),
      description: t("manage_description"),
      onSelect: onManage,
    },
  ];
}

/* Topics. Synthesised rather than "Option N" so the windowed list, both paging demos, the
   minimum-query demo and the topic picker all read as a real forum. The banks are sized to be
   coprime with each other so titles do not fall into a short repeating cycle, and they produce
   lengths from roughly 25 to 90 characters. The `#<id>` suffix keeps every title unique, which
   is what lets the cursor-source spec narrow to a single row. */
const TOPIC_VERBS = [
  "Rethinking",
  "Debugging",
  "Migrating",
  "Documenting",
  "Benchmarking",
  "Simplifying",
  "Auditing",
  "Rolling out",
  "Deprecating",
  "Instrumenting",
  "Rewriting",
];

const TOPIC_OBJECTS = [
  "the notification pipeline",
  "category permissions",
  "the onboarding wizard",
  "search indexing",
  "the theme compiler",
  "webhook delivery",
  "avatar uploads",
  "the review queue",
  "email digests",
  "sidebar navigation",
  "chat presence",
  "the tag hierarchy",
  "full-page search",
  "the composer draft store",
];

const TOPIC_QUALIFIERS = [
  "after the 3.5 upgrade",
  "on very large sites",
  "without breaking themes",
  "for self-hosted installs",
  "under sustained load",
  "in a multisite cluster",
  "when the cache is cold",
  "",
  "",
];

const TOPIC_CATEGORIES = [
  { name: "Feature requests", color: CATEGORY_PALETTE.blue },
  { name: "Support", color: CATEGORY_PALETTE.orange },
  { name: "Documentation", color: CATEGORY_PALETTE.grey },
  { name: "Plugin development", color: CATEGORY_PALETTE.green },
  { name: "Staff", color: CATEGORY_PALETTE.red },
  { name: "Localization", color: CATEGORY_PALETTE.teal },
];

let cachedTopics = null;

/**
 * The 5,000-topic set, built once. The previous implementation rebuilt its array on every getter
 * read, and the paged loader read it per request — so a single page fetch allocated 5,000
 * objects.
 */
export function topics() {
  if (cachedTopics) {
    return cachedTopics;
  }

  cachedTopics = Array.from({ length: TOPIC_COUNT }, (_, index) => {
    const id = index + 1;
    const verb = TOPIC_VERBS[index % TOPIC_VERBS.length];
    const object = TOPIC_OBJECTS[index % TOPIC_OBJECTS.length];
    const qualifier = TOPIC_QUALIFIERS[index % TOPIC_QUALIFIERS.length];
    const title = [verb, object, qualifier].filter(Boolean).join(" ");

    return {
      id,
      // The id suffix is what keeps every title unique.
      name: `${title} #${id}`,
      category: TOPIC_CATEGORIES[index % TOPIC_CATEGORIES.length],
      replies: (index * 7) % 143,
      daysAgo: (index % 90) + 1,
    };
  });

  return cachedTopics;
}

function matches(item, filter, field = "name") {
  if (!filter) {
    return true;
  }
  return String(item[field] ?? "")
    .toLowerCase()
    .includes(filter.toLowerCase());
}

/**
 * Builds a paginated `@load`.
 *
 * @param {object} options
 * @param {Array} options.items - the full set to page over.
 * @param {number} [options.pageSize]
 * @param {number} [options.delayMs]
 * @param {"total"|"hasMore"|"none"} [options.report] - how the source describes what remains.
 *   `none` means silence, which the engine reads as "this page is the whole set".
 * @param {number} [options.fakeTotal] - claim a total the source cannot actually deliver, to
 *   exercise the engine's exhaustion brake.
 */
export function makePagedLoader({
  items,
  pageSize = PAGE_SIZE,
  delayMs = 900,
  report = "total",
  fakeTotal = null,
}) {
  return async (filter, { signal, offset = 0, limit = pageSize } = {}) => {
    await delay(signal, delayMs);

    const filtered = items.filter((item) => matches(item, filter));
    const page = filtered.slice(offset, offset + limit);

    if (report === "none") {
      return page;
    }

    if (report === "hasMore") {
      return { items: page, hasMore: offset + page.length < filtered.length };
    }

    return { items: page, total: fakeTotal ?? filtered.length };
  };
}

/**
 * Builds a `@load` that fails on purpose.
 *
 * @param {object} options
 * @param {Array} options.items - returned by the requests that succeed. Required: without it the
 *   retry the error examples exist to demonstrate would throw instead of recovering.
 * @param {"first"|"alternate"|"always"} [options.failOn] - `first` fails only the opening
 *   request, which is what the smoke test's error-state assertion depends on. `alternate` leaves
 *   the state reachable more than once per page load.
 * @param {number} [options.delayMs]
 * @param {string} [options.message]
 */
export function makeFailingLoader({
  items,
  failOn = "first",
  delayMs = 750,
  message = "The source could not be reached.",
}) {
  let requests = 0;

  const loader = async (filter, { signal } = {}) => {
    await delay(signal, delayMs);
    requests += 1;

    const shouldFail =
      failOn === "always" ||
      (failOn === "first" && requests === 1) ||
      (failOn === "alternate" && requests % 2 === 1);

    if (shouldFail) {
      throw new Error(message);
    }

    return items.filter((item) => matches(item, filter));
  };

  // Lets an example reset the source so the error state is inspectable more than once per page
  // load, instead of being a one-shot accident of request ordering.
  loader.reset = () => (requests = 0);

  return loader;
}

/**
 * Builds a slow `@load` alongside a live tally of what happened to each request, so a reader can
 * cause an abort and watch it being honoured rather than taking the claim on trust.
 */
export function makeInstrumentedLoader({ items, delayMs = 2000 }) {
  const stats = { started: 0, aborted: 0, resolved: 0 };

  const load = async (filter, { signal } = {}) => {
    stats.started += 1;
    try {
      await delay(signal, delayMs);
    } catch (error) {
      stats.aborted += 1;
      throw error;
    }
    stats.resolved += 1;
    return items.filter((item) => matches(item, filter));
  };

  return { load, stats };
}
