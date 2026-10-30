# discourse-adplugin — DFP / GAM category targeting

How to target Google Ad Manager (DFP/GAM) ads per category using this plugin, with no
theme component or code changes.

## What the feature does

Each category can define its own GAM ad unit and keywords. When a page inside that
category renders a DFP ad, the plugin requests the category's ad unit and passes the
category's keywords as targeting. Categories with no configuration fall back to the
globally configured ad unit.

- `gam_adunit` — the full GPT ad unit path for that category
  (e.g. `/6355419/Travel/Europe/France/Paris`). Leave blank to use the fallback.
- `gam_keywords` — comma-separated targeting values for that category
  (e.g. `travel,europe`).
- `gtm_taxonomy` — optional taxonomy string exposed to theme components (e.g. to push
  into `window.dataLayer`). The plugin stores it but does not use it itself.

## Prerequisites

1. The `discourse-adplugin` plugin is **enabled** (`discourse_adplugin_enabled`).
2. DFP/GAM is configured: `dfp_publisher_id` is set and at least one DFP ad placement is
   in use (e.g. `dfp_topic_list_top_code`).
3. The ad units you reference exist in your GAM network.

## Local testing without a GAM account

Google provides a test network and ad units that can be used without a GAM account. Do
not copy this configuration to a production site.

1. In the site settings admin, set:

   ```yaml
   discourse_adplugin_enabled: true
   dfp_publisher_id: 6355419
   dfp_topic_list_top_code: Travel/Europe
   dfp_topic_list_top_ad_sizes: "300*250 - medium rectangle"
   ```

   `dfp_topic_list_top_*` creates a slot on category pages. To test the same
   category override inside a topic, also set:

   ```yaml
   dfp_topic_above_post_stream_code: Travel/Europe
   dfp_topic_above_post_stream_ad_sizes: "300*250 - medium rectangle"
   ```

2. Open **Admin → Plugins → discourse-adplugin → DFP / GAM**, click **Add category
   configuration**, and select a public category:

   ```text
   GAM ad unit:  /6355419/Travel/Europe/France/Paris
   GAM keywords: local-test,category-override
   GTM taxonomy: local/test
   ```

3. Reload the site in a logged-out browser window and visit the configured category.
   Logged-out testing avoids the normal group settings that can hide ads from staff.
4. Open the browser console and inspect the active slots:

   ```js
   googletag.pubads().getSlots().map((slot) => ({
     adUnitPath: slot.getAdUnitPath(),
     targeting: slot.getConfig("targeting").targeting,
   }));
   ```

   The category page should report the Paris ad unit, `gam_keywords` containing both
   configured keywords, and `discourse-category` containing the category slug.
5. Navigate without a full reload to an unconfigured category. Its ad unit should
   change to `/6355419/Travel/Europe`, while `discourse-category` changes to the new
   slug. Returning to the configured category should restore the Paris ad unit.

The visual test creative may be inspected with Google's Publisher Console by adding
`?google_console=1` to the page URL. Once the full GPT library has loaded,
`googletag.openConsole()` opens the same console. The slot and targeting output above is
the authoritative check for this feature even if an ad blocker, consent configuration,
or network policy prevents the creative from rendering. See
[Google's test-ad guide](https://developers.google.com/publisher-tag/guides/get-started)
and [Publisher Console guide](https://developers.google.com/publisher-tag/guides/publisher-console).

## Step 1 — Configure the fallback (site settings)

Set the default ad unit that unconfigured categories (and private/special categories)
use. It is built from `dfp_publisher_id` + the per-placement `dfp_*_code` settings:

```yaml
dfp_publisher_id: 6355419
dfp_topic_list_top_code: Travel          # → /6355419/Travel
dfp_topic_above_post_stream_code: Travel
dfp_post_bottom_code: Travel
dfp_topic_list_top_ad_sizes: "728*90 - leaderboard"
```

## Step 2 — Set per-category values (admin)

Open **Admin → Plugins → discourse-adplugin → DFP / GAM**, click **Add category
configuration**, and select a category:

| Field | Example for "Paris" | Example for "Europe" |
|---|---|---|
| GAM ad unit | `/6355419/Travel/Europe/France/Paris` | `/6355419/Travel/Europe` |
| GAM keywords | `travel,europe,france,paris` | `travel,europe` |
| GTM taxonomy | `travel/europe/france/paris` | `travel/europe` |

Rules:

- Values are saved in the plugin's per-category settings and applied wherever that
  category appears (category and topic pages, desktop and mobile).
- Leave **GAM ad unit / GAM keywords blank** to inherit the fallback — this is how
  private or special categories (e.g. Uncategorized or a private category) keep the
  fallback unit.
- Edits are pushed to connected browsers live, each viewer receiving only the
  categories they can see (restricted-category config reaches just the members
  allowed to view it).

## How the ad unit is resolved

For each placement the plugin resolves, in priority order, the first match:

1. `dfp-ad-config` value transformer registered by a theme component/plugin (if any).
2. The plugin dashboard's per-category setting.
3. Legacy category custom fields, when present.
4. The site settings (`dfp_publisher_id` + `dfp_*_code`).

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
  unit (e.g. `/6355419/Travel`) serves descendants, which is what covers blank /
  special categories.
- Per-category keywords arrive as the `gam_keywords` key-value (Slug).

## Advanced — extend with a transformer (theme components)

Power users can override or extend the resolved ad config from a theme component. The
transformer receives the current `value` and a `context` with `placement`,
`categorySlug`, `categoryPath`, `categoryId`, `routeName`, `customFields`, and
`categoryConfig`:

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

Registering a transformer is optional — without it the site settings and per-category
dashboard configuration above apply.

## Tests

```sh
bin/qunit --standalone plugins/discourse-adplugin/test/javascripts/
```

Covers `dfpConfig` resolution (site settings, legacy category custom fields, dashboard
configuration, and transformers), the configuration UI, and DFP advertising behaviour.
