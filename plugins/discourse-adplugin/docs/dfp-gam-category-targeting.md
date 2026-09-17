# DFP/GAM category targeting

How to target Google Ad Manager (DFP/GAM) ads per Discourse category — via the
`dfp-ad-config` value transformer introduced in `discourse-adplugin`.

This covers the scenario where a site has per-**category** ad configuration, e.g. the
"forums" of a migrated community are now Discourse categories, and each one exposes:

| category example | gam_adunit | gam_keywords | gtm_taxonomy |
|---|---|---|---|
| Cards Talk | `/8438/stltoday.com/sports/forums/cards-talk` | `sports,mlb,St. Louis Cardinals, Baseball` | `sports/forums/cards-talk` |
| Food Talk | `/8438/stltoday.com/life-entertainment/forums/food-talk` | `entertainment,food,drink` | `life-entertainment/forums/food-talk` |
| Limbo (private/special) | `/8438/stltoday.com/forums` (fallback) | | `forums/misc` |

---

## How a DFP request works

Every GPT ad request is two parts:

```
give me an ad for AD UNIT   /8438/stltoday.com/forums
          with KEY-VALUES   discourse-category = cards-talk
```

- **Ad unit** — *where* to look for inventory (the slot you created in GAM).
- **Key-values (custom targeting)** — *notes* about the page used to pick a line item;
  keys no line item uses are ignored.

The `discourse-adplugin` already stamps one key-value automatically on every DFP
impression (`google-dfp-ad.gjs`, `dfpConfig`):

```
discourse-category = <current category leaf slug>     e.g. "cards-talk"
                     or "0" when there is no category  e.g. Limbo, Probation, Search, Home
```

This is pre-existing behavior and requires no code.

---

## The `dfp-ad-config` transformer (what the plugin now exposes)

`discourse-adplugin` adds a value transformer named **`dfp-ad-config`**. A theme
component or plugin registers a callback that can override the resolved ad config per
placement/category. The callback receives:

```js
{
  value:   { adUnitPath, targeting },   // the current/default config
  context: {
    placement,        // "topic-list-top", "topic-above-post-stream", ...
    categorySlug,     // leaf slug or null
    categoryPath,     // ["sports","cards-talk"]  (root → leaf)
    categoryId,
    routeName,        // e.g. "discovery.category", "topic."
  },
}
```

It returns `{ adUnitPath?, targeting? }`:

- `adUnitPath` — full GPT ad unit, e.g. `/8438/stltoday.com/sports/forums/cards-talk`.
- `targeting` — object merged over the configured `dfp_target_*` settings, e.g.
  `{ gam_keywords: ["sports","mlb"] }`.

No override registered → behavior is unchanged (default path from `dfp_publisher_id` +
`dfp_*_code`, targeting from `dfp_target_*` settings, `discourse-category` always set).

Files involved:

- `assets/javascripts/discourse/pre-initializers/dfp-ad-config-transformer.js` — registers the transformer name.
- `assets/javascripts/discourse/components/google-dfp-ad.gjs` — `dfpConfig()`, `defineSlot()`, `updated()` (redefines the slot when the ad unit path changes on navigation), `#buildDfpContext()`.
- `assets/javascripts/discourse/components/ad-component.js` — `currentCategoryPath`.
- `test/javascripts/unit/dfp-config-test.js` — unit tests.

---

## Option 1 — GAM targeting on `discourse-category` (no code)

The key-value is already sent; you only configure GAM.

**GAM console:**

1. *Delivery → Custom targeting → New key*: `discourse-category` (String). Values = your category slugs + `0`.
2. Line item → *Inventory*: select the parent ad unit (e.g. `/8438/stltoday.com/sports/forums`; GAM serves line items to descendants).
3. Line item → *Targeting*: `discourse-category IS ONE OF cards-talk, mizzou-talk, ...`
4. Special/private categories (Limbo, Probation, Hidden, Recycle Bin) → `discourse-category = 0`; serve them with a `0`-targeted line item or a parent-unit line item.

**Covers:** per-category targeting + special-category fallback, reporting by category.
**Does not cover:** distinct per-category ad-unit URLs (`gam_adunit`) or per-category
`gam_keywords` (only a single static set via `dfp_target_*_key_code/value_code`).

---

## Option 2 — per-category targeting overrides (static ad unit)

Ship the plugin files. The theme component returns **`targeting` only**; the ad-unit URL
stays the same for every category.

**Site settings:**

```yaml
dfp_publisher_id: 8438
dfp_topic_list_top_code: stltoday.com/forums
```

**Theme component:**

```js
import { apiInitializer } from "discourse/lib/api";

const KEYWORDS = {
  "food-talk":  ["entertainment", "food", "drink"],
  "cards-talk": ["sports", "mlb", "St. Louis Cardinals", "Baseball"],
  // ...
};

export default apiInitializer((api) => {
  api.registerValueTransformer("dfp-ad-config", ({ value, context }) => {
    const keywords = KEYWORDS[context.categorySlug];
    return keywords
      ? {
          ...value, // keep default adUnitPath + discourse-category
          targeting: {
            "discourse-category-path": context.categoryPath.join("/"),
            gam_keywords: keywords,
          },
        }
      : value;
  });
});
```

**Resulting request:**

```
defineSlot("/8438/stltoday.com/forums", [728,90], "div-gpt-ad-1-topic-list-top")
  targeting: { discourse-category: "cards-talk",
               discourse-category-path: "sports/forums/cards-talk",
               gam_keywords: ["sports","mlb"] }
```

**GAM console:** line items target key-values (`gam_keywords IS ONE OF ...`).
No slot churn on navigation (refresh only). Cost: GAM line items must be re-keyed off
key-values instead of ad-unit hierarchy.

---

## Option 3 — per-category ad unit paths

Ship the plugin files. The theme component returns **`adUnitPath`** per category, from
the `gam_adunit` column; unlisted categories fall back to the configured default unit.

**Site settings (fallback for special/private categories):**

```yaml
dfp_publisher_id: 8438
dfp_topic_list_top_code: stltoday.com/forums    # → /8438/stltoday.com/forums
```

**Theme component:**

```js
import { apiInitializer } from "discourse/lib/api";

const FORUMS = {
  "food-talk":  { adUnit: "/8438/stltoday.com/life-entertainment/forums/food-talk",
                  keywords: ["entertainment", "food", "drink"] },
  "cards-talk": { adUnit: "/8438/stltoday.com/sports/forums/cards-talk",
                  keywords: ["sports", "mlb", "St. Louis Cardinals", "Baseball"] },
  // ...rest of the table
};

export default apiInitializer((api) => {
  api.registerValueTransformer("dfp-ad-config", ({ value, context }) => {
    const forum = FORUMS[context.categorySlug];
    if (!forum) {
      return value; // → /8438/stltoday.com/forums
    }
    return forum.keywords
      ? { ...value, adUnitPath: forum.adUnit, targeting: { gam_keywords: forum.keywords } }
      : { ...value, adUnitPath: forum.adUnit };
  });
});
```

**Resulting request:**

```
# on Cards Talk
defineSlot("/8438/stltoday.com/sports/forums/cards-talk", ...)
  targeting: { discourse-category: "cards-talk", gam_keywords: ["sports","mlb"] }

# on Limbo / Probation (unlisted)
defineSlot("/8438/stltoday.com/forums", ...)
  targeting: { discourse-category: "0" }
```

On navigation the plugin compares the resolved `adUnitPath` with the current slot's and
**destroys + redefines** the slot when it changes, because GPT pins the ad unit at slot
creation. **GAM console:** no re-keying; keep the existing ad-unit hierarchy, and the
fallback unit serves the special categories.

---

## Option comparison

| | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| What changes in the request | nothing (existing key) | key-values only | the ad-unit URL |
| Ad unit inventory | one per placement | one per placement | full hierarchy |
| Navigation cost | refresh | refresh | destroy + redefine |
| Special-category fallback | via `discourse-category = 0` | via `discourse-category = 0` | parent `/…/forums` unit |
| GAM console | build line items on key | re-key line items on key-values | keep path-based line items |
| Code needed | none | theme component | theme component |

---

## Supplying the mapping (admin setup)

### Today: theme component map

The safest immediate path is a hardcoded map in the theme component (see Options 2/3).
Downside: requires editing theme code when categories change.

### Recommended: category custom fields (implemented in the plugin)

`gam_adunit`, `gam_keywords` and `gtm_taxonomy` can be set as **category custom fields**
via the plugin's per-category settings section (Admin → Categories → *category* → GAM/DFP).
Category JSON always includes `custom_fields` (`app/serializers/category_serializer.rb`),
so the fields are readable client-side.

The plugin reads them natively: `dfpConfig` applies `gam_adunit` → `adUnitPath` and
`gam_keywords` → targeting automatically (`google-dfp-ad.gjs`, `applyCategoryCustomFields`),
with the `dfp-ad-config` transformer still able to override them. **No theme component is
required** for the common case.

A theme component that only needs to *extend* (rather than replace) the behavior gets the
fields through the transformer context:

```js
api.registerValueTransformer("dfp-ad-config", ({ value, context }) => {
  return { ...value, targeting: { gtm_taxonomy: context.customFields.gtm_taxonomy } };
});
```

Bonus: the same fields can drive GTM (the site's component pushes `cf.gtm_taxonomy` into
`window.dataLayer`), giving GTM and GAM one source of truth.

### Alternative: theme component settings

A theme setting (list or JSON) editable under *Admin → Customize → Themes* for admins
who don't want custom fields.

---

## GAM console checklist

- [ ] Custom targeting key `discourse-category` registered (values = category slugs + `0`)
- [ ] Ad units exist at the paths used (`/8438/stltoday.com/forums`, per-category children)
- [ ] Line items: inventory on parent unit (descendant matching), criteria on `discourse-category` and/or `gam_keywords`
- [ ] Special/private categories covered (`discourse-category = 0` or parent-unit line item)
- [ ] If Option 2/3: theme component registered `dfp-ad-config`, unit tests pass

---

## Making it plugin-native (status)

The category-custom-fields path is **implemented**:

- `dfpConfig` resolves ad units from configured `dfp_*` settings → category custom fields
  (`gam_adunit`/`gam_keywords`) → `dfp-ad-config` transformer (last wins).
- Per-category admin UI in the `category-custom-settings` outlet
  (`dfp-ad-category-settings.gjs`) with i18n.
- The transformer context includes `customFields` for theme components that extend behavior.

Remaining optional polish:

- **A — Built-in category custom fields.** Done above; the plugin already ships it.
- **B — Site-setting JSON map.** Add a site setting holding
  `{ "<category-slug>": { adunit: "...", keywords: "..." } }`. Only worth it if a site
  wants to keep the map out of category custom fields.
- **C — Ship a sample theme component.** Keep the transformer, bundle a ready-made
  theme-component template with the plugin/docs so sites copy it wholesale.

**Status of this doc's implementation:** the `dfp-ad-config` transformer, slot
redefinition on navigation, `currentCategoryPath`, category custom fields natively
resolved in `dfpConfig`, the per-category admin settings connector, i18n, and unit +
integration tests are all implemented.
