---
title: Badge availability
short_title: Badge availability
id: badge-availability
---

`Badge.enabled` selects stored administrator preferences. `Badge.available` also requires the owning plugin to be enabled; `badge.available?` provides the same check for a record. Public listings and grants use availability. Admin interfaces keep unavailable badges editable.

## Plugin API

Declare an optional extra setting in `plugin.rb`:

```ruby
badge_enabled_setting :example_badges_enabled
```

Seed badges from a fixture:

```ruby
plugin = Discourse.plugins_by_name.fetch("example")
plugin.seed_badge("Example Badge") do |badge|
  badge.badge_type_id = BadgeType::Bronze
  badge.default_enabled = true
end
```

The optional extra setting combines with the plugin's enabled setting. `seed_badge` finds or creates by exact name, assigns ownership, and rejects another plugin's badge. The block receives a badge record; use existing `default_*` setters for creation-only preferences. Names remain globally unique. Ownership survives renaming and regrouping; missing plugins make their badges unavailable.

Listings and cached user summaries reflect availability immediately. Summary cache versions add one aggregate badge query per request. Awards and individual preferences are retained.
