# discourse-adplugin — DFP / GAM category targeting

How to target Google Ad Manager (DFP/GAM) ads per category using this plugin, with no
theme component and no code changes.

For the full technical deep-dive (how the plug rules compose, the `dfp-ad-config` value
transformer, examples for every option), see
[`dfp-gam-category-targeting.md`](./dfp-gam-category-targeting.md).

## What the feature does

Each category can define its own GAM ad unit and keywords. When a page inside that
category renders a DFP ad, the plugin requests the category's ad unit and passes the
category's keywords as targeting. Categories with no configuration fall back to the
globally configured ad unit.

- `gam_adunit` — the full GPT ad unit path for that category
  (e.g. `/8438/stltoday.com/sports/forums/cards-talk`). Leave blank to use the fallback.
- `gam_keywords` — comma-separated targeting values for that category
  (e.g. `sports,mlb`).
- `gtm_taxonomy` — optional taxonomy string exposed to theme components (e.g. to push
  into `window.dataLayer`). Stored on the category for you; the plugin does not use it
  itself.

## Prerequisites

1. The `discourse-adplugin` plugin is **enabled** (`discourse_adplugin_enabled`).
2. DFP/GAM is configured: `dfp_publisher_id` is set and at least one DFP ad placement is
   in use (e.g. `dfp_topic_list_top_code`).
3. The ad units you reference exist in your GAM network.

## Step 1 — Configure the fallback (site settings)

Set the default ad unit that unconfigured categories (and private/special categories)
use. It is built from `dfp_publisher_id` + the per-placement `dfp_*_code` settings:

```yaml
dfp_publisher_id: 8438
dfp_topic_list_top_code: stltoday.com/forums          # → /8438/stltoday.com/forums
dfp_topic_above_post_stream_code: stltoday.com/forums
dfp_post_bottom_code: stltoday.com/forums
dfp_topic_list_top_ad_sizes: "728*90 - leaderboard"
```

## Step 2 — Set per-category values (admin)

Admin → **Categories** → open a category → the **GAM / DFP** section:

| Field | Example for "Cards Talk" | Example for "Food Talk" |
|---|---|---|
| GAM ad unit | `/8438/stltoday.com/sports/forums/cards-talk` | `/8438/stltoday.com/life-entertainment/forums/food-talk` |
| GAM keywords | `sports,mlb,St. Louis Cardinals, Baseball` | `entertainment,food,drink` |
| GTM taxonomy | `sports/forums/cards-talk` | `life-entertainment/forums/food-talk` |

Rules:

- Values are saved as category custom fields (`gam_adunit`, `gam_keywords`,
  `gtm_taxonomy`) and applied wherever that category appears (category and topic pages,
  desktop and mobile).
- Leave **GAM ad unit / GAM keywords blank** to inherit the fallback — this is how
  private or special categories (e.g. Limbo, Probation, Recycle Bin) keep the fallback
  unit.
- There is no migration: these are free-form custom fields; editing takes effect on the
  next page load.

## How the ad unit is resolved

For each placement the plugin resolves, in priority order, the first match:

1. `dfp-ad-config` value transformer registered by a theme component/plugin (if any).
2. The category's `gam_adunit` custom field.
3. The site settings (`dfp_publisher_id` + `dfp_*_code`).

Keywords (`gam_keywords`) are merged into the slot targeting over any configured
`dfp_target_*` values, and `discourse-category` is always set to the category's leaf slug
(or `"0"` when there is no category) so GAM line items and reporting can use it.

When you navigate from one category to another and the ad unit changes, the plugin
destroys and redefines the GPT slot so the new ad unit is requested (GPT pins the ad unit
at slot-creation time — a plain refresh would keep the old one).

## How to configure GAM

- Register `discourse-category` (String) as a custom-targeting key in GAM if you want
  line-item targeting or reporting by category.
- Keep your line items on the **ad-unit hierarchy** — a line item targeting a parent
  unit (e.g. `/8438/stltoday.com/forums`) serves descendants, which is what covers blank /
  special categories.
- Per-category keywords arrive as the `gam_keywords` key-value (Slug).

## Advanced — extend with a transformer (theme components)

Power users can override or extend the resolved ad config from a theme component. The
transformer receives the current `value` and a `context` with `placement`,
`categorySlug`, `categoryPath`, `categoryId`, `routeName` and `customFields`:

```js
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer("dfp-ad-config", ({ value, context }) => {
    if (context.categorySlug === "special-case") {
      return {
        ...value,
        adUnitPath: "/1234/custom/ad-unit",
        targeting: { gam_keywords: ["custom"] },
      };
    }
    return value;
  });
});
```

Registering a transformer is optional — without it the settings + category custom fields
behaviour above applies.

## Tests

```sh
bin/qunit --standalone plugins/discourse-adplugin/test/javascripts/
```

Covers `dfpConfig` resolution (settings, category custom fields, transformer), the
per-category settings connector, and DFP advertising behaviour.
