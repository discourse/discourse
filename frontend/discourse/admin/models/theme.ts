/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import { computed, get } from "@ember/object";
import { isBlank, isEmpty } from "@ember/utils";
import type { SettingValue } from "discourse/admin/models/site-setting";
import ThemeSettings, {
  type ThemeSettingsFields,
} from "discourse/admin/models/theme-settings";
import ThemeSiteSettings, {
  type ThemeSiteSettingsFields,
} from "discourse/admin/models/theme-site-settings";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import RestModel, {
  type RestModelClass,
  type RestModelStoreAttrs,
  type RestPayload,
} from "discourse/models/rest";
import { i18n } from "discourse-i18n";

const THEME_UPLOAD_VAR = 2;
const FIELDS_IDS = [0, 1, 5, 6];

export const THEMES = "themes" as const;
export const COMPONENTS = "components" as const;
const SETTINGS_TYPE_ID = 5;

const JS_FILENAME = "discourse/api-initializers/theme-initializer.gjs";

/** The basic serializer used in raw parent/child relationships. */
export interface BasicTheme {
  id: number;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
  default?: boolean;
  component: boolean;
}

/** Field payload; remote themes omit source values, and deletion clears values/uploads. */
export interface ThemeField {
  name: string;
  target: string | null;
  type_id: number;
  value?: string | null;
  file_path?: string | null;
  error?: string;
  upload_id?: number | null;
  url?: string;
  filename?: string;
  migrated?: boolean;
}

/** Remote metadata is nullable independently of whether the remote record exists. */
export interface RemoteTheme {
  id: number;
  remote_url: string;
  remote_version: string | null;
  local_version: string | null;
  commits_behind: number | null;
  branch: string | null;
  local_compat_ref: string | null;
  remote_compat_ref: string | null;
  remote_updated_at: string | null;
  updated_at: string;
  github_diff_link?: string;
  last_error_text: string | null;
  is_git: boolean;
  license_url: string | null;
  about_url: string | null;
  authors: string | null;
  theme_version: string | null;
  minimum_discourse_version: string | null;
  maximum_discourse_version: string | null;
  has_private_key: boolean;
}

/** Raw translations become ThemeSettings only when the translations panel loads them. */
export interface ThemeTranslation {
  key: string;
  value: SettingValue;
  default: SettingValue;
}

/** Embedded serializer data, not a hydrated ColorScheme model. */
export interface ThemeColorScheme {
  id: number;
  name: string;
  is_base: boolean | null;
  base_scheme_id: number | null;
  theme_id: number | null;
  theme_name: string | null;
  user_selectable: boolean;
  is_builtin_default: boolean | null;
  is_dark: boolean;
  colors: {
    name: string;
    hex: string;
    default_hex: string | null;
    is_advanced: boolean;
  }[];
}

/** Embedded user/name/title serializer data. */
export interface ThemeUser {
  id: number;
  username: string;
  avatar_template: string;
  name?: string | null;
  title: string | null;
}

/** Full editor fields and mutable UI state; index/create payloads can omit editor data. Plugins augment here. */
export interface ThemeFields extends BasicTheme {
  color_scheme_id: number | null;
  dark_color_scheme_id: number | null;
  remote_theme_id: number | null;
  user_selectable?: boolean;
  auto_update?: boolean;
  supported?: boolean;
  enabled?: boolean;
  system?: boolean;
  only_theme_color_schemes?: boolean;
  screenshot_light_url?: string | null;
  screenshot_dark_url?: string | null;
  settings?: ThemeSettings[] | null;
  themeable_site_settings?: ThemeSiteSettings[];
  child_themes?: BasicTheme[];
  parent_themes?: BasicTheme[];
  remote_theme?: RemoteTheme | null;
  color_scheme?: ThemeColorScheme | null;
  user?: ThemeUser;
  disabled_by?: ThemeUser | null;
  disabled_at?: string | null;
  errors?: string[];
  translations?: (ThemeTranslation | ThemeSettings)[];
  loadingTranslations?: boolean;
  locale?: string;
  markedToDelete?: boolean;
  selected?: boolean;
}

/** munge accepts raw setting records as well as previously hydrated settings. */
export type ThemeCreateAttrs<M = Theme> = Omit<
  Partial<M>,
  "settings" | "themeable_site_settings"
> &
  RestModelStoreAttrs &
  RestPayload & {
    settings?: Partial<Omit<ThemeSettingsFields, "updateSetting">>[] | null;
    themeable_site_settings?: Partial<
      Omit<ThemeSiteSettingsFields, "updateSetting">
    >[];
  };

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
interface Theme extends ThemeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
class Theme extends RestModel {
  /** Uses RestModel's runtime factory, whose munge hydrates the nested settings. */
  declare static create: <C extends RestModelClass>(
    this: C,
    attrs?: ThemeCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  static munge(json: ThemeCreateAttrs): RestPayload;
  static munge(json: RestPayload): RestPayload;
  static munge(json: ThemeCreateAttrs) {
    if (json.settings) {
      json.settings = json.settings.map((setting) =>
        ThemeSettings.create(setting)
      );
    }

    if (json.themeable_site_settings) {
      json.themeable_site_settings = json.themeable_site_settings.map(
        (setting) => ThemeSiteSettings.create(setting)
      );
    }

    return json;
  }

  @autoTrackedArray childThemes?: Theme[];
  @autoTrackedArray parentThemes?: Theme[];

  /** Full editor records supply fields; partial records initialize them lazily in themeFields. */
  @autoTrackedArray theme_fields!: ThemeField[];

  changed = false;

  @computed("default", "user_selectable")
  get isActive() {
    return this.default || this.user_selectable;
  }

  @computed("remote_theme.commits_behind")
  get isPendingUpdates() {
    // Missing counters still participate in the original JavaScript comparison.
    return (this.remote_theme?.commits_behind as number) > 0;
  }

  @computed("editedFields.length")
  get hasEditedFields() {
    return (this.editedFields?.length as number) > 0;
  }

  @computed("parent_themes.length")
  get hasParents() {
    return (this.parent_themes?.length as number) > 0;
  }

  @computed("theme_fields.[]")
  get targets() {
    return (
      [
        { id: 0, name: "common" },
        { id: 1, name: "desktop", icon: "desktop" },
        { id: 2, name: "mobile", icon: "mobile-screen-button" },
      ] as {
        id: number;
        name: string;
        icon?: string;
        edited?: boolean;
        error?: boolean;
      }[]
    ).map((target) => {
      target["edited"] = this.hasEdited(target.name);
      target["error"] = this.hasError(target.name);
      return target;
    });
  }

  @computed("theme_fields.[]")
  get fieldNames() {
    const common = [
      "scss",
      "head_tag",
      "header",
      "after_header",
      "body_tag",
      "footer",
    ];

    return {
      common: [
        ...common,
        "js",
        "color_definitions",
        "embedded_scss",
        "embedded_header",
      ],
      desktop: common,
      mobile: common,
    };
  }

  @computed("fieldNames", "theme_fields.[]", "theme_fields.@each.error")
  get fields() {
    const hash: Record<
      string,
      {
        name: string;
        edited: boolean;
        error: boolean;
        translatedName?: string;
        title?: string;
        icon?: string;
      }[]
    > = {};
    Object.keys(this.fieldNames).forEach((target) => {
      hash[target] = this.fieldNames[
        target as keyof typeof this.fieldNames
      ].map((fieldName) => {
        const field: {
          name: string;
          edited: boolean;
          error: boolean;
          translatedName?: string;
          title?: string;
          icon?: string;
        } = {
          name: fieldName,
          edited: this.hasEdited(target, fieldName),
          error: this.hasError(target, fieldName),
        };

        field.translatedName = i18n(`admin.customize.theme.${fieldName}.text`);
        field.title = i18n(`admin.customize.theme.${fieldName}.title`);

        if (fieldName.indexOf("_tag") > 0) {
          field.icon = "far-file-lines";
        }

        return field;
      });
    });
    return hash;
  }

  @computed("theme_fields")
  get themeFields(): Record<string, ThemeField> {
    if (!this.theme_fields) {
      this.set("theme_fields", []); // eslint-disable-line ember/no-side-effects
      return {};
    }

    let hash: Record<string, ThemeField> = {};
    this.theme_fields.forEach((field) => {
      if (!field.type_id || FIELDS_IDS.includes(field.type_id)) {
        hash[this.getKey(field)] = field;
      }
    });
    return hash;
  }

  @computed("theme_fields", "theme_fields.[]")
  get uploads() {
    if (!this.theme_fields) {
      return [];
    }
    return this.theme_fields.filter(
      (f) => f.target === "common" && f.type_id === THEME_UPLOAD_VAR
    );
  }

  @computed("theme_fields", "theme_fields.@each.error")
  get isBroken(): boolean | undefined {
    return (
      this.theme_fields &&
      this.theme_fields.some((field) => field.error && field.error.length > 0)
    );
  }

  @computed("theme_fields.[]")
  get editedFields(): ThemeField[] | undefined {
    return this.theme_fields?.filter(
      (field) => !isBlank(field.value) && field.type_id !== SETTINGS_TYPE_ID
    );
  }

  @computed("remote_theme.last_error_text")
  get remoteError() {
    if (
      this.remote_theme?.last_error_text &&
      this.remote_theme?.last_error_text?.length > 0
    ) {
      return this.remote_theme?.last_error_text;
    }
  }

  @computed("childThemes.[]")
  get child_theme_ids() {
    if (this.childThemes) {
      return this.childThemes?.map((theme) => get(theme, "id"));
    }
  }

  @computed("component", "enabled", "hasParents")
  get warnUnassignedComponent() {
    return this.component && this.enabled && !this.hasParents;
  }

  getKey(field: Pick<ThemeField, "target" | "name">): string {
    return `${field.target} ${field.name}`;
  }

  hasEdited(target: string, name?: string): boolean {
    if (name) {
      return !isEmpty(this.getField(target, name));
    } else {
      let fields = this.theme_fields || [];
      return fields.some(
        (field) => field.target === target && !isEmpty(field.value)
      );
    }
  }

  hasError(target: string, name?: string): boolean {
    return this.theme_fields
      .filter((f) => f.target === target && (!name || name === f.name))
      .some((f) => f.error);
  }

  getError(target: string, name: string): string | undefined {
    let themeFields = this.themeFields;
    let key = this.getKey({ target, name });
    let field = themeFields[key];
    return field ? field.error : "";
  }

  /** Source editing uses local payloads, which include field values. */
  getField(target: string, name: string): string | null {
    if (target === "common" && name === "js") {
      target = "extra_js";
      name = JS_FILENAME;
    }
    let themeFields = this.themeFields;
    let key = this.getKey({ target, name });
    let field = themeFields[key];
    return field ? (field.value as string | null) : "";
  }

  removeField(field: ThemeField) {
    this.set("changed", true);

    field.upload_id = null;
    field.value = null;

    return this.saveChanges("theme_fields");
  }

  setField(target: string, name: string, value: string | null): void;
  setField(
    target: string,
    name: string,
    value: string | null,
    upload_id: number | null,
    type_id: number
  ): void;

  setField(
    target: string,
    name: string,
    value: string | null,
    upload_id?: number | null,
    type_id?: number
  ): void {
    this.set("changed", true);

    // Normalize JS field target/name consistently with getField()
    if (target === "common" && name === "js") {
      target = "extra_js";
      name = JS_FILENAME;
    }

    let themeFields = this.themeFields;
    // Three-argument editor calls stage fields without type_id until the server saves them.
    let field = { name, target, value, upload_id, type_id } as ThemeField;

    // slow path for uploads and so on
    if (type_id && type_id > 1) {
      let fields = this.theme_fields;
      let existing = fields.find(
        (f) => f.target === target && f.name === name && f.type_id === type_id
      );
      if (existing) {
        existing.value = value;
        existing.upload_id = upload_id;
      } else {
        fields.push(field);
      }
      return;
    }

    // fast path
    let key = this.getKey({ target, name });
    let existingField = themeFields[key];
    if (!existingField) {
      this.theme_fields.push(field);
      themeFields[key] = field;
    } else {
      const changed =
        (isEmpty(existingField.value) && !isEmpty(value)) ||
        (isEmpty(value) && !isEmpty(existingField.value));

      existingField.value = value;
      if (changed) {
        // Observing theme_fields.@each.value is too slow, so manually notify
        // if the value goes to/from blank
        this.notifyPropertyChange("theme_fields.[]");
      }
    }
  }

  removeChildTheme(theme: Theme) {
    // Keep the adapter-hydrated relationship precondition; missing children still reach the helper.
    removeValueFromArray(this.childThemes!, theme);
    return this.saveChanges("child_theme_ids");
  }

  addChildTheme(theme: Theme) {
    let childThemes = this.childThemes;
    if (!childThemes) {
      childThemes = [];
      this.set("childThemes", childThemes);
    }

    removeValueFromArray(childThemes, theme);
    childThemes.push(theme);

    return this.saveChanges("child_theme_ids");
  }

  addParentTheme(theme: Theme) {
    let parentThemes = this.parentThemes;
    if (!parentThemes) {
      parentThemes = [];
      this.set("parentThemes", parentThemes);
    }

    addUniqueValueToArray(parentThemes, theme);
  }

  checkForUpdates() {
    return this.save({ remote_check: true }).then(() =>
      this.set("changed", false)
    );
  }

  updateToLatest() {
    return this.save({ remote_update: true }).then(() =>
      this.set("changed", false)
    );
  }

  /** Saves the named properties; the implementation intentionally has zero formal parameters. */
  saveChanges(...keys: (keyof this & string)[]): Promise<boolean | void>;
  saveChanges() {
    // apply consumes the array-like arguments object without changing the method arity.
    // eslint-disable-next-line prefer-spread
    const hash = this.getProperties.apply(
      this,
      // eslint-disable-next-line prefer-rest-params
      arguments as unknown as (keyof this & string)[]
    );
    return this.save(hash)
      .then(() => true)
      .finally(() => this.set("changed", false))
      .catch(popupAjaxError);
  }
}

export default Theme;

declare module "discourse/services/store" {
  interface ModelRegistry {
    theme: Theme;
  }

  interface ModelCreateAttrsRegistry {
    theme: ThemeCreateAttrs<Theme>;
  }
}
