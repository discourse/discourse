/**
 * Fixtures for the `DSelect` styleguide page.
 *
 * The page is the only surface rendering `DSelect`, so its data is what a reader judges the
 * component by. Placeholder content ("Orange", "Option 1…5000") makes even a correct component
 * look unfinished, so the tiers below are shaped to be worth reading: real writing systems in
 * tier 1, people with roles in tier 2, plausible topics in tier 3.
 *
 * ── LOAD-BEARING CONSTRAINTS ────────────────────────────────────────────────────────────────
 * System specs read these exact shapes. Most of them fail SILENTLY when broken — the assertion
 * still passes while its intent has moved — so each one names the spec that depends on it.
 *
 *   LOCALES.length >= 15            large enough to scroll a panel; tier-1 default everywhere
 *   FOUR_OPTIONS.length === 4       d_select_no_probe_spec: `count: 4` and aria-setsize "4"
 *   FOUR_OPTIONS[0..2] labels       d_select_multi_chip_roving_spec: three chips added in order,
 *                                   then asserted by label and by DOM order
 *   ASYNC_BUTTON_DELAY === 1200     d_select_no_probe_spec: its `wait: 10` and `sleep 4` budget
 *                                   are sized against three of these
 *   TOPIC_COUNT === 5000            d_select_bounded_reveal_spec: aria-setsize "5000", and
 *                                   reveal_to_index(4999) must reach exactly 4999
 *   "#4242" appears in exactly one  d_select_cursor_source_spec: filtering must narrow to a
 *   topic title                     single row. Any second occurrence breaks `count: 1`
 *   PAGE_SIZE === 50 over 5000      d_select_cursor_source_spec: the first response must be
 *                                   incomplete, so the source reports setsize -1 while paging
 *   error source fails request #1   smoke_test_spec: "shows the muted source-error state"
 *   only, then succeeds
 *   MAXIMUM === 3, seeded at cap    smoke_test_spec: renders .d-combobox__limit plus a
 *                                   disabled option
 *   multi example seeded []         d_select_multi_chip_roving_spec: starts from no chips
 *   TEAMS spans >= 2 groups         smoke_test_spec: `.d-combobox__group-header` minimum: 2
 *   REVIEWER_IDS.length === 7       d_select_showcases_spec: exactly 7 resolved chips
 *   REVIEWER_IDS includes 999       d_select_showcases_spec: unresolvable -> "deleted-user"
 *   PEOPLE has username "maya"      d_select_showcases_spec: chip label assertion
 *   Taylor Kim is disabled AND      d_select_showcases_spec: asserts a disabled option exists
 *   not pre-selected
 *   TAGS excludes "architecture"    d_select_showcases_spec: the create-a-tag flow needs it to
 *                                   be genuinely absent
 *   reviewer control stays narrow   d_select_showcases_spec: reviewer_chips_wrapped? compares
 *   enough for 7 chips to wrap      offsetTop. NARROWING is safe; WIDENING breaks it
 * ────────────────────────────────────────────────────────────────────────────────────────────
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

/* Tier 1 — interface languages. The default fixture for anything whose subject is a mechanism
   rather than markup. Endonyms are literals, not display strings, so they are not translated —
   and they carry three writing systems and two RTL scripts, which makes RTL and non-Latin the
   page's ordinary content instead of a quarantined "hostile input" demo. */
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

/** The four-row subset the "silent source" spec counts. Order matters: the first three are the
 *  labels the chip-roving spec adds and then asserts by DOM order. */
export const FOUR_OPTIONS = LOCALES.slice(0, 4);

export const ASYNC_BUTTON_DELAY = 1200;
export const MAXIMUM = 3;
export const PAGE_SIZE = 50;
export const TOPIC_COUNT = 5000;

/* Tier 2 — people. Every person carries a role and some carry a status, because an identity row
   with only a name and a handle reads as a mock. Avatars are local SVGs rather than the shared
   `/images/avatar.png`: twelve identical grey circles was the single most damaging thing on the
   old page, and letter avatars are not an option because the avatar proxy is disabled under
   `Rails.env.test?`, so every screenshot would capture blanks. */
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
];

/** Seven seeded reviewer ids, one of which (999) resolves to nothing so the unresolved fallback
 *  is exercised. Seven is also what makes the chips wrap in a 28rem control. */
export const REVIEWER_IDS = [101, 102, 103, 104, 105, 106, 999];

export const TEAMS = {
  design: "Design",
  engineering: "Engineering",
  support: "Support",
};

export const TEAM_MEMBERS = [
  { ...PEOPLE[0], team: "design" },
  { ...PEOPLE[7], team: "design" },
  { ...PEOPLE[1], team: "engineering" },
  { ...PEOPLE[4], team: "engineering" },
  { ...PEOPLE[6], team: "support" },
];

/** Deliberately excludes "architecture" — the create-a-tag flow creates exactly that. */
export const TAGS = [
  { slug: "design-system", label: "design-system", count: 128 },
  { slug: "accessibility", label: "accessibility", count: 94 },
  { slug: "performance", label: "performance", count: 71 },
  { slug: "onboarding", label: "onboarding", count: 55 },
  { slug: "theming", label: "theming", count: 42 },
  { slug: "migrations", label: "migrations", count: 30 },
  { slug: "release-notes", label: "release-notes", count: 22 },
  { slug: "localization", label: "localization", count: 17 },
];

/* Tier 3 — topics. Synthesised rather than "Option N" so the windowed list, both paging demos,
   the minimum-query demo and the topic picker all read as a real forum. The `#<id>` suffix keeps
   every title unique, which is what lets the cursor-source spec narrow to a single row. */
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
];

const TOPIC_QUALIFIERS = [
  "after the 3.5 upgrade",
  "on very large sites",
  "without breaking themes",
  "for self-hosted installs",
  "under sustained load",
  "in a multisite cluster",
  "",
];

const TOPIC_CATEGORIES = [
  { name: "Feature", color: "0088CC" },
  { name: "Support", color: "E45735" },
  { name: "Dev", color: "9EB83B" },
  { name: "Documentation", color: "808281" },
  { name: "Meta", color: "BF1E2E" },
];

let cachedTopics = null;

/**
 * The 5,000-topic set, built once. The previous implementation rebuilt its array on every getter
 * read, and the paged loader read it per request — so a single page fetch allocated 5,000 objects.
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
 * @param {"first"|"alternate"|"always"} [options.failOn] - `first` fails only the opening
 *   request, which is what the smoke test's error-state assertion depends on.
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
