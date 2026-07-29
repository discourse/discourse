import { trustHTML } from "@ember/template";
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
 *   ASYNC_BUTTON_DELAY === 1200     d_select_no_probe_spec: its `wait: 10` and `sleep 4` budget
 *   TOPIC_COUNT === 5000            d_select_bounded_reveal_spec: aria-setsize "5000", and
 *                                   reveal_to_index(4999) must reach exactly 4999
 *   "#4242" ends exactly one topic  d_select_cursor_source_spec: filtering must narrow to a
 *                                   single row. Any second occurrence breaks `count: 1`
 *   PAGE_SIZE === 50 over 5000      d_select_cursor_source_spec: the first response must be
 *                                   incomplete, so the source reports setsize -1 while paging
 *   PEOPLE has username "maya"      d_select_showcases_spec: chip label assertion
 *   Taylor Kim is disabled AND      d_select_showcases_spec: asserts a disabled option exists
 *   not pre-selected
 *   TAGS excludes "architecture"    d_select_showcases_spec: the create-a-tag flow needs it to
 *                                   be genuinely absent
 *   TEAM_MEMBERS spans >= 2 teams   smoke_test_spec: `.d-combobox__group-header` minimum: 2
 */

/** Rejects when `signal` aborts, otherwise resolves after `ms`. */
function delay(signal, ms = 750) {
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

const ASYNC_BUTTON_DELAY = 1200;
const PAGE_SIZE = 50;
const TOPIC_COUNT = 5000;

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

/* Letter avatars are not an option because the avatar proxy is disabled under
   `Rails.env.test?`, so screenshots would capture blanks.

   Optional fields are deliberately uneven — a couple carry a status, one carries no title at
   all, one name is long enough to wrap. A set where every row has every field is the tell of a
   mock; real member lists are ragged. */
export const PEOPLE = [
  {
    id: 101,
    username: "maya",
    name: "Maya Alvarez",
    title: "Design lead",
    avatarColors: ["#E8734A", "#F4C7A1", "#743F93"],
  },
  {
    id: 102,
    username: "devon",
    name: "Devon Park",
    title: "Frontend",
    avatarColors: ["#3C6FD1", "#E5B990", "#183F7A"],
  },
  {
    id: 103,
    username: "ines",
    name: "Inés Rojas",
    title: "Accessibility",
    avatarColors: ["#5A8F52", "#C98665", "#315E38"],
    status: "On leave until Friday",
  },
  {
    id: 104,
    username: "kwame",
    name: "Kwame Boateng",
    title: "Security",
    avatarColors: ["#C4453F", "#6F412D", "#F3C96B"],
  },
  {
    id: 105,
    username: "sora",
    name: "Sora Tanaka",
    title: "Performance",
    avatarColors: ["#6B54B8", "#E1B28F", "#393070"],
  },
  {
    id: 106,
    username: "noor",
    name: "Noor Haddad",
    title: "Documentation",
    avatarColors: ["#C79A22", "#B97855", "#356B75"],
  },
  {
    id: 107,
    username: "taylor",
    name: "Taylor Kim",
    title: "Support",
    avatarColors: ["#5E6B78", "#E4B897", "#2D4658"],
    // Not pre-selected, and disabled: the showcases spec asserts a disabled option renders.
    disabled: true,
  },
  {
    id: 108,
    username: "lucia",
    name: "Lucía Ferrer",
    title: "Community",
    avatarColors: ["#BE4A7E", "#DFA582", "#6A2449"],
  },
  // The long-name row. Nothing else on the page forces a two-line name to wrap inside a row or
  // truncate inside a chip.
  {
    id: 109,
    username: "annelies",
    name: "Annelies van der Meer-Okonkwo",
    title: "Internationalisation",
    avatarColors: ["#1F8A8A", "#F0C8A7", "#114E5A"],
    status: "Reviewing translations",
  },
  {
    id: 110,
    username: "rafa",
    name: "Rafa Ortiz",
    avatarColors: ["#7D4A9E", "#C98763", "#40305B"],
  },
  {
    id: 111,
    username: "wei",
    name: "Wei Zhang",
    title: "Infrastructure",
    avatarColors: ["#B8860B", "#E0B18E", "#5D3D20"],
  },
  {
    id: 112,
    username: "amara",
    name: "Amara Nwosu",
    title: "Trust and safety",
    avatarColors: ["#2E7D4F", "#74452F", "#E5B84B"],
    status: "Back Monday",
  },
].map(({ avatarColors, ...person }) => ({
  ...person,
  avatarStyle: trustHTML(
    `--avatar-background: ${avatarColors[0]}; --avatar-head: ${avatarColors[1]}; --avatar-body: ${avatarColors[2]}`
  ),
}));

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

function currentOffsetMinutes(timeZone, now) {
  const name = new Intl.DateTimeFormat("en-US", {
    timeZone,
    timeZoneName: "longOffset",
  })
    .formatToParts(now)
    .find((part) => part.type === "timeZoneName").value;

  if (name === "GMT") {
    return 0;
  }

  const [, sign, hours, minutes] = name.match(/^GMT([+-])(\d{2}):(\d{2})$/);
  const magnitude = Number(hours) * 60 + Number(minutes);
  return sign === "-" ? -magnitude : magnitude;
}

function offsetLabel(offsetMinutes) {
  if (offsetMinutes === 0) {
    return "0";
  }

  const sign = offsetMinutes < 0 ? "-" : "+";
  const magnitude = Math.abs(offsetMinutes);
  const hours = Math.floor(magnitude / 60);
  const minutes = magnitude % 60;

  return `${sign}${hours}${minutes ? `:${String(minutes).padStart(2, "0")}` : ""}`;
}

/* Multiple cities per offset keep the divider example from separating every row. */
const TIMEZONE_NOW = new Date();

export const TIMEZONES = [
  { id: "honolulu", name: "Honolulu", timeZone: "Pacific/Honolulu" },
  { id: "papeete", name: "Papeete", timeZone: "Pacific/Tahiti" },
  { id: "rarotonga", name: "Rarotonga", timeZone: "Pacific/Rarotonga" },
  { id: "los-angeles", name: "Los Angeles", timeZone: "America/Los_Angeles" },
  { id: "phoenix", name: "Phoenix", timeZone: "America/Phoenix" },
  { id: "vancouver", name: "Vancouver", timeZone: "America/Vancouver" },
  { id: "chicago", name: "Chicago", timeZone: "America/Chicago" },
  { id: "lima", name: "Lima", timeZone: "America/Lima" },
  { id: "winnipeg", name: "Winnipeg", timeZone: "America/Winnipeg" },
  { id: "new-york", name: "New York", timeZone: "America/New_York" },
  {
    id: "santo-domingo",
    name: "Santo Domingo",
    timeZone: "America/Santo_Domingo",
  },
  { id: "toronto", name: "Toronto", timeZone: "America/Toronto" },
  {
    id: "buenos-aires",
    name: "Buenos Aires",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  { id: "montevideo", name: "Montevideo", timeZone: "America/Montevideo" },
  { id: "sao-paulo", name: "São Paulo", timeZone: "America/Sao_Paulo" },
  { id: "accra", name: "Accra", timeZone: "Africa/Accra" },
  { id: "dakar", name: "Dakar", timeZone: "Africa/Dakar" },
  { id: "reykjavik", name: "Reykjavík", timeZone: "Atlantic/Reykjavik" },
  { id: "lagos", name: "Lagos", timeZone: "Africa/Lagos" },
  { id: "lisbon", name: "Lisbon", timeZone: "Europe/Lisbon" },
  { id: "london", name: "London", timeZone: "Europe/London" },
  { id: "berlin", name: "Berlin", timeZone: "Europe/Berlin" },
  {
    id: "johannesburg",
    name: "Johannesburg",
    timeZone: "Africa/Johannesburg",
  },
  { id: "paris", name: "Paris", timeZone: "Europe/Paris" },
  { id: "istanbul", name: "Istanbul", timeZone: "Europe/Istanbul" },
  { id: "nairobi", name: "Nairobi", timeZone: "Africa/Nairobi" },
  { id: "riyadh", name: "Riyadh", timeZone: "Asia/Riyadh" },
  { id: "colombo", name: "Colombo", timeZone: "Asia/Colombo" },
  { id: "kolkata", name: "Kolkata", timeZone: "Asia/Kolkata" },
  { id: "mumbai", name: "Mumbai", timeZone: "Asia/Kolkata" },
  { id: "beijing", name: "Beijing", timeZone: "Asia/Shanghai" },
  { id: "perth", name: "Perth", timeZone: "Australia/Perth" },
  { id: "singapore", name: "Singapore", timeZone: "Asia/Singapore" },
  { id: "osaka", name: "Osaka", timeZone: "Asia/Tokyo" },
  { id: "seoul", name: "Seoul", timeZone: "Asia/Seoul" },
  { id: "tokyo", name: "Tokyo", timeZone: "Asia/Tokyo" },
  { id: "brisbane", name: "Brisbane", timeZone: "Australia/Brisbane" },
  { id: "guam", name: "Guam", timeZone: "Pacific/Guam" },
  {
    id: "port-moresby",
    name: "Port Moresby",
    timeZone: "Pacific/Port_Moresby",
  },
  { id: "auckland", name: "Auckland", timeZone: "Pacific/Auckland" },
  { id: "suva", name: "Suva", timeZone: "Pacific/Fiji" },
  { id: "tarawa", name: "Tarawa", timeZone: "Pacific/Tarawa" },
]
  .map((city) => {
    const offsetMinutes = currentOffsetMinutes(city.timeZone, TIMEZONE_NOW);

    return {
      ...city,
      offsetMinutes,
      offset: offsetLabel(offsetMinutes),
    };
  })
  .sort(
    (left, right) =>
      left.offsetMinutes - right.offsetMinutes ||
      left.name.localeCompare(right.name)
  );

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
      icon: "d-muted",
      title: t("muted"),
      description: t("muted_description"),
    },
    {
      level: "normal",
      icon: "d-regular",
      title: t("normal"),
      description: t("normal_description"),
    },
    {
      level: "tracking",
      icon: "d-tracking",
      title: t("tracking"),
      description: t("tracking_description"),
    },
    {
      level: "watching",
      icon: "d-watching",
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
   minimum-query demo and the topic picker all read as a real forum. Each bank advances by a
   different stride so the combinations vary across pages. The `#<id>` suffix keeps every title
   unique, which is what lets the cursor-source spec narrow to a single row. */
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
  "Hardening",
  "Profiling",
  "Untangling",
  "Shipping",
  "Testing",
  "Securing",
  "Localizing",
  "Redesigning",
  "Restoring",
  "Scaling",
  "Monitoring",
  "Modernizing",
  "Extending",
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
  "onebox previews",
  "mobile navigation",
  "the admin sidebar",
  "topic timers",
  "bulk user actions",
  "badge queries",
  "the plugin outlet API",
  "theme component settings",
  "the post revision viewer",
  "rate-limit telemetry",
  "the user directory",
  "category banners",
  "keyboard navigation",
  "upload cleanup",
  "the translation workflow",
  "real-time topic updates",
  "the digest scheduler",
  "group mention rules",
  "moderation history",
  "anonymous browsing",
];

const TOPIC_QUALIFIERS = [
  "after the 3.5 upgrade",
  "on very large sites",
  "without breaking themes",
  "for self-hosted installs",
  "under sustained load",
  "in a multisite cluster",
  "when the cache is cold",
  "with strict content security policies",
  "for keyboard-only navigation",
  "across light and dark themes",
  "on unreliable connections",
  "while preserving old URLs",
  "with millions of posts",
  "for multilingual communities",
  "behind a reverse proxy",
  "during rolling deploys",
  "without extra database queries",
  "on narrow mobile screens",
  "with custom plugins enabled",
  "after restoring a backup",
  "for high-traffic events",
  "without surprising moderators",
  "",
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
    const verb = TOPIC_VERBS[(index * 5) % TOPIC_VERBS.length];
    const object = TOPIC_OBJECTS[(index * 7) % TOPIC_OBJECTS.length];
    const qualifier = TOPIC_QUALIFIERS[(index * 11) % TOPIC_QUALIFIERS.length];
    const title = [verb, object, qualifier].filter(Boolean).join(" ");

    return {
      id,
      // The id suffix is what keeps every title unique.
      name: `${title} #${id}`,
      category: TOPIC_CATEGORIES[(index * 5) % TOPIC_CATEGORIES.length],
      replies: (index * 7) % 143,
      daysAgo: (index % 90) + 1,
    };
  });

  return cachedTopics;
}

function matches(item, filter, fields = ["name"]) {
  if (!filter) {
    return true;
  }

  return fields
    .map((field) => item[field] ?? "")
    .join(" ")
    .toLowerCase()
    .includes(filter.toLowerCase());
}

/**
 * Builds the API boundary used by the asynchronous select examples.
 *
 * @param {object} options
 * @param {Array} options.items
 * @param {Array<string>} [options.fields]
 * @param {"first"|"always"} [options.failOn]
 * @param {string} [options.message]
 * @param {number} [options.pageSize]
 * @param {number} [options.resolveDelayMs]
 * @param {"total"|"hasMore"|"none"} [options.report] - how the source describes what remains.
 * @param {number} [options.searchDelayMs]
 */
function createDataSource({
  items,
  fields = ["name"],
  failOn = null,
  message = "The source could not be reached.",
  pageSize = PAGE_SIZE,
  resolveDelayMs = 0,
  report = "total",
  searchDelayMs = 750,
}) {
  let requests = 0;

  const search = async (
    filter,
    { signal, offset = 0, limit = pageSize } = {}
  ) => {
    await delay(signal, searchDelayMs);
    requests += 1;

    if (failOn === "always" || (failOn === "first" && requests === 1)) {
      throw new Error(message);
    }

    const filtered = items.filter((item) => matches(item, filter, fields));

    if (report === "none") {
      return filtered;
    }

    const page = filtered.slice(offset, offset + limit);

    if (report === "hasMore") {
      return { items: page, hasMore: offset + page.length < filtered.length };
    }

    return { items: page, total: filtered.length };
  };

  const findItem = (value) => items.find((item) => item.id === value);
  const findItems = (values) =>
    items.filter((item) => values.includes(item.id));

  const find = resolveDelayMs
    ? async (value, { signal } = {}) => {
        await delay(signal, resolveDelayMs);
        return findItem(value);
      }
    : findItem;

  const findMany = resolveDelayMs
    ? async (values, { signal } = {}) => {
        await delay(signal, resolveDelayMs);
        return findItems(values);
      }
    : findItems;

  const source = { find, findMany, search };

  if (failOn) {
    source.reset = () => (requests = 0);
  }

  return source;
}

export function createRetryingLocaleApi() {
  return createDataSource({
    items: LOCALES,
    failOn: "first",
    message: i18n("styleguide.sections.select.request_error"),
    report: "none",
  });
}

export function createRetryingPeopleApi() {
  return createDataSource({
    items: PEOPLE,
    failOn: "first",
    report: "none",
    searchDelayMs: 600,
  });
}

export const activityFilterApi = createDataSource({
  items: [
    { id: "all", name: "All activity" },
    { id: "following", name: "Topics I follow" },
    { id: "mentions", name: "Mentions" },
    { id: "unread", name: "Unread topics" },
  ],
  report: "none",
  searchDelayMs: ASYNC_BUTTON_DELAY,
});

export const cursorTopicApi = createDataSource({
  items: topics(),
  report: "hasMore",
  searchDelayMs: 900,
});

export const emptyApi = createDataSource({
  items: [],
  report: "none",
  searchDelayMs: 400,
});

export const fastTopicApi = createDataSource({
  items: topics(),
  report: "total",
  searchDelayMs: 120,
});

export const localeApi = createDataSource({
  items: LOCALES,
  report: "none",
  searchDelayMs: ASYNC_BUTTON_DELAY,
});

export const pagedTopicApi = createDataSource({
  items: topics(),
  report: "total",
  searchDelayMs: 900,
});

export const peopleApi = createDataSource({
  items: PEOPLE,
  report: "none",
  searchDelayMs: 400,
});

export const reviewerApi = createDataSource({
  items: PEOPLE,
  fields: ["name", "username", "title"],
  report: "none",
  resolveDelayMs: 500,
  searchDelayMs: 650,
});

export const unavailableApi = createDataSource({
  items: [],
  failOn: "always",
  report: "none",
  searchDelayMs: 400,
});
