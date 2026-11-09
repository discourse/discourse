import type EmberObject from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { expectTypeOf } from "expect-type";
import SiteSetting, {
  isSettingValueTrue,
} from "discourse/admin/models/site-setting";
import Theme, {
  COMPONENTS,
  type ThemeCreateAttrs,
  type ThemeField,
  THEMES,
} from "discourse/admin/models/theme";
import ThemeSettings from "discourse/admin/models/theme-settings";
import ThemeSiteSettings from "discourse/admin/models/theme-site-settings";
import type RestModel from "discourse/models/rest";
import type {
  default as StoreService,
  ModelFor,
  ResultSetOf,
} from "discourse/services/store";

declare const store: StoreService;

/* SiteSetting: `/admin/site_settings` rows, where every value is a string. */

expectTypeOf<Awaited<ReturnType<typeof SiteSetting.findAll>>>().toEqualTypeOf<
  { nameKey: string; name: string; siteSettings: SiteSetting[] }[]
>();
SiteSetting.findAll();
SiteSetting.findAll({ filter_names: ["title"] });
expectTypeOf(
  SiteSetting.findByName("title")
).resolves.toEqualTypeOf<SiteSetting>();
SiteSetting.update("title", "New title");
SiteSetting.update("enable_welcome_banner", false);
SiteSetting.update("default_other_new_topic_duration_minutes", "10", {
  updateExistingUsers: true,
});
SiteSetting.bulkUpdate({ title: { value: "A" } });

declare const setting: SiteSetting;
expectTypeOf(setting).toExtend<EmberObject>();
expectTypeOf(setting).not.toBeAny();
expectTypeOf(setting.setting).toEqualTypeOf<string>();
expectTypeOf(setting.type).toEqualTypeOf<string>();
expectTypeOf(setting.humanized_name).toEqualTypeOf<string>();
expectTypeOf(setting.isSaving).toEqualTypeOf<boolean>();
expectTypeOf(setting.validationMessage).toEqualTypeOf<
  string | TrustedHTML | null
>();
expectTypeOf(setting.updateExistingUsers).toEqualTypeOf<boolean>();
// Editors write strings, but plugins and the schema route also store booleans and parsed objects.
setting.value = "true";
setting.set("value", false);
expectTypeOf(setting.overridden).toEqualTypeOf<boolean>();
expectTypeOf(setting.requiresConfirmation).toEqualTypeOf<boolean>();
expectTypeOf(setting.requiresReload).toEqualTypeOf<boolean>();
expectTypeOf(setting.affectsExistingUsers).toEqualTypeOf<boolean>();
expectTypeOf(setting.hasPendingChanges).toEqualTypeOf<boolean>();
expectTypeOf(setting.settingSubtype).toEqualTypeOf<
  "textarea" | "password" | undefined
>();
expectTypeOf(setting.staffLogFilter).toEqualTypeOf<
  { subject: string; action_name: string } | undefined
>();
expectTypeOf(setting.buffered).not.toBeAny();
expectTypeOf(setting.commit()).toEqualTypeOf<void>();
expectTypeOf(setting.rollback()).toEqualTypeOf<void>();
setting.setUpdateExistingUsers(true);
// Optional metadata the controls read.
expectTypeOf(setting.min).toEqualTypeOf<number | undefined>();
expectTypeOf(setting.upload).toEqualTypeOf<
  | {
      original_filename: string;
      human_filesize: string;
      width: number | null;
      height: number | null;
    }
  | undefined
>();
expectTypeOf(isSettingValueTrue("true")).toEqualTypeOf<boolean>();
isSettingValueTrue(true);
isSettingValueTrue(null);
// The theme selectors build settings client-side.
SiteSetting.create({
  setting: "parent_theme_ids",
  type: "list",
  list_type: "compact",
  allow_any: false,
  preview: null,
  value: "",
  default: "",
  choices: ["Light", "Dark"],
});

/* ThemeSettings: a theme's settings, whose values follow the setting type. */

declare const themeSetting: ThemeSettings;
expectTypeOf(themeSetting).toExtend<SiteSetting>();
themeSetting.value = 51;
themeSetting.value = true;
themeSetting.value = null;
themeSetting.value = [{ name: "section", links: [] }];
expectTypeOf(themeSetting.objects_schema).not.toBeAny();
themeSetting.updateSetting(1, [{ name: "section" }]);
themeSetting.loadMetadata(1);
expectTypeOf(themeSetting.metadata?.property_descriptions).toEqualTypeOf<
  Record<string, string> | undefined
>();
// Translations reuse this class without a setting name or type.
ThemeSettings.create({
  key: "greeting",
  value: "Hello",
  default: "Hello",
  textarea: true,
});

/* ThemeSiteSettings: site settings a theme can override; values are strings. */

declare const themeSiteSetting: ThemeSiteSettings;
expectTypeOf(themeSiteSetting).toExtend<SiteSetting>();
themeSiteSetting.updateSetting(1, "false");

/* Theme: `/admin/themes` records. */

expectTypeOf(THEMES).toEqualTypeOf<"themes">();
expectTypeOf(COMPONENTS).toEqualTypeOf<"components">();
expectTypeOf<ModelFor<"theme">>().toEqualTypeOf<Theme>();
expectTypeOf(store.findAll("theme")).resolves.toEqualTypeOf<
  ResultSetOf<Theme> | undefined
>();
Theme.create({ id: 1, name: "Light", __type: "theme", __state: "created" });

declare const theme: Theme;
expectTypeOf(theme).toExtend<RestModel>();
expectTypeOf(theme.id).toEqualTypeOf<number>();
expectTypeOf(theme.name).toEqualTypeOf<string>();
expectTypeOf(theme.description).toEqualTypeOf<string | null>();
expectTypeOf(theme.component).toEqualTypeOf<boolean>();
// Only the default theme sends `default`.
expectTypeOf(theme.default).toEqualTypeOf<boolean | undefined>();
expectTypeOf(theme.color_scheme_id).toEqualTypeOf<number | null>();
expectTypeOf(theme.dark_color_scheme_id).toEqualTypeOf<number | null>();
expectTypeOf(theme.remote_theme_id).toEqualTypeOf<number | null>();
expectTypeOf(theme.screenshot_light_url).toEqualTypeOf<
  string | null | undefined
>();
// Invalid settings YAML sends null.
expectTypeOf(theme.settings).toEqualTypeOf<
  ThemeSettings[] | null | undefined
>();
// Components omit themeable site settings.
expectTypeOf(theme.themeable_site_settings).toEqualTypeOf<
  ThemeSiteSettings[] | undefined
>();
expectTypeOf(theme.remote_theme?.commits_behind).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(theme.remote_theme?.branch).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(theme.childThemes).toEqualTypeOf<Theme[] | undefined>();
expectTypeOf(theme.child_themes?.[0]?.name).toEqualTypeOf<string | undefined>();
expectTypeOf(theme.theme_fields[0].type_id).toEqualTypeOf<number>();
// Deleting a field clears its value and upload.
theme.theme_fields[0].value = null;
theme.theme_fields[0].upload_id = null;
expectTypeOf(theme.changed).toEqualTypeOf<boolean>();
expectTypeOf(theme.getField("common", "scss")).toEqualTypeOf<string | null>();
theme.setField("common", "scss", "body {}");
theme.setField("common", "logo", "", 7, 2);
theme.saveChanges("name", "color_scheme_id");
theme.addChildTheme(theme);
theme.removeChildTheme(theme);
// The color palette manager assigns ids or clears them.
theme.color_scheme_id = 5;
theme.dark_color_scheme_id = null;
// The translations panel stores what it loads.
theme.translations = [{ key: "greeting", value: "Hello", default: "Hello" }];

/* Subclassing, schema-route values and partial payloads. */

expectTypeOf<typeof SiteSetting>().toExtend<typeof EmberObject>();
expectTypeOf<typeof ThemeSettings>().toExtend<typeof SiteSetting>();
expectTypeOf<typeof ThemeSiteSettings>().toExtend<typeof SiteSetting>();
// findByName creates through SiteSetting explicitly, even on a subclass.
expectTypeOf(
  ThemeSettings.findByName("title")
).resolves.toEqualTypeOf<SiteSetting>();
expectTypeOf(themeSiteSetting.value).toEqualTypeOf<string>();
expectTypeOf(setting.value).not.toBeAny();
setting.value = { sections: [{ visible: true, id: 1 }] };
setting.overridden = false;
setting.computedValueProperty = "value";
setting.computedNameProperty = null;
expectTypeOf<SiteSetting["computedNameProperty"]>().toEqualTypeOf<
  string | null
>();
setting.validValues = ["one", { name: "Two", value: 2 }];
expectTypeOf(setting.validValues).not.toBeAny();
setting.allowsNone = "admin.settings.none";
setting.anyValue = true;
expectTypeOf(setting.buffered.get("value")).toEqualTypeOf<
  SiteSetting["value"]
>();
SiteSetting.bulkUpdate({ title: { value: "A", backfill: false } });
expectTypeOf(themeSetting.loadMetadata(1)).not.toBeAny();

expectTypeOf<ModelFor<"Theme">>().toEqualTypeOf<Theme>();
expectTypeOf<ThemeCreateAttrs["name"]>().toEqualTypeOf<string | undefined>();
expectTypeOf<ThemeCreateAttrs["color_scheme_id"]>().toEqualTypeOf<
  number | null | undefined
>();
Theme.create({
  settings: [{ setting: "count", type: "integer", value: 2, default: 1 }],
});
Theme.create({ settings: [{ type: "list", resolve_group_membership: true }] });
Theme.munge({
  settings: null,
  themeable_site_settings: [{ setting: "title", value: "A", default: "B" }],
});
// The themes index serializer sends partial records.
Theme.create({ id: 1, name: "Partial index record" });
expectTypeOf(theme.isActive).toEqualTypeOf<boolean | undefined>();
expectTypeOf(theme.editedFields).toEqualTypeOf<ThemeField[] | undefined>();
expectTypeOf(theme.isBroken).toEqualTypeOf<boolean | undefined>();
expectTypeOf(theme.remoteError).toEqualTypeOf<string | undefined>();
expectTypeOf(theme.child_theme_ids).toEqualTypeOf<number[] | undefined>();
expectTypeOf(theme.parentThemes).toEqualTypeOf<Theme[] | undefined>();
