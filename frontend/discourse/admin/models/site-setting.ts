import { tracked } from "@glimmer/tracking";
import EmberObject, { computed, set } from "@ember/object";
import type ObjectProxy from "@ember/object/proxy";
import { type TrustedHTML, trustHTML } from "@ember/template";
import {
  DEFAULT_USER_PREFERENCES,
  SITE_SETTING_REQUIRES_CONFIRMATION_TYPES,
} from "discourse/admin/lib/constants";
import SettingObjectHelper from "discourse/admin/lib/setting-object-helper";
import type Theme from "discourse/admin/models/theme";
import { ajax } from "discourse/lib/ajax";
import BufferedProxy from "discourse/lib/buffered-proxy";
import { bind } from "discourse/lib/decorators";
import { deepEqual } from "discourse/lib/object";
import { applyValueTransformer } from "discourse/lib/transformer";
import type { CategoryFields } from "discourse/models/category";
import { i18n } from "discourse-i18n";

/** JSON-compatible values, including parsed schema edits and theme setting values. */
export type SettingValue =
  | string
  | number
  | boolean
  | null
  | SettingValue[]
  | { [key: string]: SettingValue };

/** Enum providers may attach additional metadata to their choices. */
export type SettingChoice =
  | string
  | number
  | boolean
  | {
      name?: string;
      value?: SettingValue;
      [key: string]: unknown;
    };

/** Schema keywords are configuration-defined, including nested object schemas. */
export type SettingSchema = Record<string, unknown>;

/** Shared optional metadata; configuration can attach it independently of the type. */
export interface SettingTypeMetadata {
  min?: number;
  max?: number;
  choices?: SettingChoice[];
  valid_values?: SettingChoice[];
  translate_names?: boolean;
  list_type?: string | null;
  textarea?: boolean;
  allow_any?: boolean;
  schema?: SettingSchema;
  json_schema?: SettingSchema;
  objects_schema?: SettingSchema;
  authorized_extensions?: string;
  max_file_size_kb?: number;
}

/** The admin site-settings endpoint stringifies values even for numeric and boolean types. */
export interface SiteSettingWireRecord extends SettingTypeMetadata {
  setting: string;
  type: string;
  humanized_name: string;
  description: string;
  category: string;
  value: string;
  /** Seeded upload defaults can resolve to no upload. */
  default: string | null;
  keywords?: string[];
  primary_area?: string | null;
  preview?: string | null;
  secret?: boolean;
  placeholder?: string | Record<string, unknown> | null;
  mandatory_values?: string | null;
  disallowed_groups?: string | null;
  requires_confirmation?: string | null;
  themeable?: boolean | null;
  depends_on?: string[];
  depends_on_humanized_names?: string[];
  depends_behavior?: string | null;
  depends_on_values?: Record<string, SettingValue[]>;
  dependent_setting_display?: string;
  upcoming_change?: Record<string, unknown> | null;
  upcoming_change_default_override_metadata?: {
    old_default: string;
    new_default: string;
    change_setting_name: string;
  };
  plugin?: string;
  upload?: {
    original_filename: string;
    human_filesize: string;
    width: number | null;
    height: number | null;
  };
}

/** Schema editors fill these caches lazily; category entries can also be client models. */
export interface SettingMetadata {
  categories?: Record<string, Partial<CategoryFields>>;
  property_descriptions?: Record<string, string>;
}

/** Payload metadata plus core client editor state; plugins augment this interface. */
export interface SiteSettingFields extends Omit<
  Partial<SiteSettingWireRecord>,
  "setting" | "type" | "humanized_name" | "value" | "default"
> {
  setting: string;
  type: string;
  humanized_name: string;
  /** Client editors and subclasses also hold parsed JSON, booleans and numeric values. */
  value: SettingValue;
  default: SettingValue;
  key?: string;
  label?: string;
  valueProperty?: string | null;
  nameProperty?: string | null;
  disabled?: boolean;
  weight?: number;
  defaultValues?: string;
  allThemes?: Theme[];
  setDefaultValuesLabel?: string;
  metadata?: SettingMetadata;
  /** Installed by the schema route; subclasses supply theme-specific implementations. */
  updateSetting?(id: string | number, value: SettingValue): Promise<unknown>;
}

/** TODO(typescript-pending): remove this projection when SettingObjectHelper types its setting and getters. */
type TypedSettingObjectHelper = Omit<
  SettingObjectHelper,
  | "settingObj"
  | "computedValueProperty"
  | "computedNameProperty"
  | "validValues"
  | "anyValue"
> & {
  settingObj: SiteSetting;
  computedValueProperty: string | null;
  computedNameProperty: string | null;
  validValues: SettingChoice[];
  anyValue: boolean | undefined;
};

/** TODO(typescript-pending): use BufferedProxy's content generic once it publishes one. */
type SettingBufferedProxy = ObjectProxy<SiteSetting> & {
  buffer: Partial<SiteSetting>;
  hasBufferedChanges: boolean;
  initializeBuffer(keys?: string[]): void;
  unknownProperty(key: string): unknown;
  setUnknownProperty(key: string, value: unknown): unknown;
  applyBufferedChanges(keys?: string[]): void;
  discardBufferedChanges(keys?: string[]): void;
  applyChanges(keys?: string[]): void;
  discardChanges(keys?: string[]): void;
  hasChanged(key: string): boolean;
  hasChanges: boolean;
};

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface SiteSetting extends SiteSettingFields {}

/**
 * `true` when a value is the *enabled* state of a bool site setting: boolean
 * `true`, the string `"true"`, or any value whose `String()` is exactly `"true"`.
 * This is not general JS truthiness: `"false"` is not enabled, and is safe
 * for `null` / `undefined` (unlike calling `.toString()` on the value).
 */
export function isSettingValueTrue(value: unknown): boolean {
  return String(value) === "true";
}

const AUTO_REFRESH_ON_SAVE = [
  "logo",
  "mobile_logo",
  "base_font",
  "heading_font",
  "default_text_size",
];

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class SiteSetting extends EmberObject {
  static async findAll(
    params: object = {}
  ): Promise<{ nameKey: string; name: string; siteSettings: SiteSetting[] }[]> {
    // eslint-disable-next-line prefer-const
    let settings = await ajax<{
      site_settings: SiteSettingWireRecord[];
    }>("/admin/site_settings", { data: params });
    const categories: Record<string, SiteSetting[]> = {};
    settings.site_settings.forEach(function (s) {
      if (!categories[s.category]) {
        categories[s.category] = [];
      }
      categories[s.category].push(SiteSetting.create(s));
    });
    return Object.keys(categories).map(function (n) {
      return {
        nameKey: n,
        name: i18n("admin.site_settings.categories." + n),
        siteSettings: categories[n],
      };
    });
  }

  static findByName(name: string): Promise<SiteSetting> {
    return ajax("/admin/site_settings", {
      data: {
        names: [name],
      },
    }).then(function (settings: { site_settings: SiteSettingWireRecord[] }) {
      const setting = settings.site_settings.find((s) => s.setting === name);
      // The original factory also creates an empty instance when no matching row exists.
      return SiteSetting.create(setting!);
    });
  }

  static update(
    key: string,
    value: SettingValue,
    opts: { updateExistingUsers?: boolean } = {}
  ): Promise<void> {
    const data: Record<string, SettingValue> = {};
    data[key] = value;

    if (opts["updateExistingUsers"] === true) {
      data["update_existing_user"] = true;
    }

    return ajax(`/admin/site_settings/${key}`, { type: "PUT", data });
  }

  static bulkUpdate(
    settings: Record<string, { value: SettingValue; backfill?: boolean }>
  ): Promise<void> {
    return ajax(`/admin/site_settings/bulk_update.json`, {
      type: "PUT",
      data: { settings },
    });
  }

  @tracked isSaving = false;

  @tracked validationMessage: string | TrustedHTML | null = null;
  updateExistingUsers = false;

  settingObjectHelper = new SettingObjectHelper(
    this
  ) as TypedSettingObjectHelper;

  declare buffered: SettingBufferedProxy;

  constructor(...args: ConstructorParameters<typeof EmberObject>) {
    super(...args);
    this.buffered = BufferedProxy.create({
      content: this,
    }) as unknown as SettingBufferedProxy;
  }

  @computed("settingObjectHelper.overridden")
  get overridden(): boolean {
    return this.settingObjectHelper?.overridden;
  }

  set overridden(value: boolean) {
    set(this, "settingObjectHelper.overridden", value);
  }

  @computed("settingObjectHelper.computedValueProperty")
  get computedValueProperty(): string | null {
    return this.settingObjectHelper?.computedValueProperty;
  }

  set computedValueProperty(value: string | null) {
    set(this, "settingObjectHelper.computedValueProperty", value);
  }

  @computed("settingObjectHelper.computedNameProperty")
  get computedNameProperty(): string | null {
    return this.settingObjectHelper?.computedNameProperty;
  }

  set computedNameProperty(value: string | null) {
    set(this, "settingObjectHelper.computedNameProperty", value);
  }

  @computed("settingObjectHelper.validValues")
  get validValues(): SettingChoice[] {
    return this.settingObjectHelper?.validValues;
  }

  set validValues(value: SettingChoice[]) {
    set(this, "settingObjectHelper.validValues", value);
  }

  @computed("settingObjectHelper.allowsNone")
  get allowsNone(): string | undefined {
    return applyValueTransformer(
      "site-setting-allows-none",
      this.settingObjectHelper?.allowsNone,
      { siteSetting: this }
    );
  }

  set allowsNone(value: string | undefined) {
    set(this, "settingObjectHelper.allowsNone", value);
  }

  @computed("settingObjectHelper.anyValue")
  get anyValue(): boolean | undefined {
    return this.settingObjectHelper?.anyValue;
  }

  set anyValue(value: boolean | undefined) {
    set(this, "settingObjectHelper.anyValue", value);
  }

  @computed("setting")
  get staffLogFilter() {
    if (!this.setting) {
      return;
    }

    return {
      subject: this.setting,
      action_name: "change_site_setting",
    };
  }

  get settingSubtype(): "textarea" | "password" | undefined {
    if (this.list_type) {
      return;
    }

    if (this.textarea) {
      return "textarea";
    }

    if (this.secret) {
      return "password";
    }
  }

  get definition() {
    return {
      key: this.setting,
      label: this.humanized_name || this.setting,
      description: trustHTML(this.description!),
      type: this.type,
      list_type: this.list_type,
      subtype: this.settingSubtype,
      min: this.min,
      max: this.max,
      choices: this.choices,
      valid_values: this.validValues,
      allows_none: !!this.allowsNone,
      allow_any: this.allow_any,
      mandatory_values: this.mandatory_values,
      disallowed_groups: this.disallowed_groups,
      currentSavedValue: this.value,
    };
  }

  get pendingValue() {
    return this.buffered.get("value");
  }

  get hasPendingChanges() {
    const pending = this.pendingValue ?? "";
    const saved = this.value ?? "";

    if (this.json_schema || this.schema || this.objects_schema) {
      return !deepEqual(pending, saved);
    }
    return pending.toString() !== saved.toString();
  }

  get requiresConfirmation() {
    switch (this.requires_confirmation) {
      case SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple:
        return true;
      case SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple_on_enable: {
        const val = this.buffered?.get("value");
        return isSettingValueTrue(val);
      }
      case SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple_on_disable: {
        const val = this.buffered?.get("value");
        return !isSettingValueTrue(val);
      }
      default:
        return false;
    }
  }

  get requiresReload() {
    return AUTO_REFRESH_ON_SAVE.includes(this.setting);
  }

  get affectsExistingUsers() {
    return DEFAULT_USER_PREFERENCES.includes(this.setting);
  }

  commit() {
    this.validationMessage = null;
    this.buffered.applyChanges();
  }

  rollback() {
    this.buffered.discardChanges();
  }

  @bind
  setUpdateExistingUsers(value: boolean): void {
    this.updateExistingUsers = value;
  }
}
