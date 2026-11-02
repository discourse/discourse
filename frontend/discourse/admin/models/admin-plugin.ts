import { cached, tracked } from "@glimmer/tracking";
import { dasherize } from "@ember/string";
import { snakeCaseToCamelCase } from "discourse/lib/case-converter";
import { stripDiscoursePrefix } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

export interface AdminPluginRoute {
  location: string;
  label: string;
  use_new_show_route: boolean;
  auto_generated?: boolean;
  full_location: string;
  plugin_id?: string;
}

/**
 * `/admin/plugins` record; metadata is null when the plugin does not declare it.
 * Blank `url`, `admin_route` and `enabled_setting` are omitted, and `label` is
 * sent only for Discourse-owned plugins.
 */
export interface AdminPluginPayload {
  id: string;
  name: string;
  about: string | null;
  version: string | null;
  url?: string;
  admin_route?: AdminPluginRoute | null;
  enabled: boolean;
  enabled_setting?: string;
  has_settings: boolean;
  has_only_enabled_setting: boolean;
  humanized_name: string;
  is_official: boolean;
  is_discourse_owned: boolean;
  label?: string | null;
  commit_hash: string | null;
  commit_url: string | null;
  meta_url: string | null;
  authors: string | null;
  /** Plugin-owned data, sent only when a plugin registers some. */
  extras?: Record<string, unknown>;
}

/** The constructor copies each key, camelCased; client-built records can be sparse. */
export interface AdminPluginFields {
  id: string;
  name: string;
  about?: string | null;
  version?: string | null;
  url?: string;
  adminRoute?: AdminPluginRoute | null;
  enabledSetting?: string;
  hasSettings?: boolean;
  hasOnlyEnabledSetting?: boolean;
  humanizedName?: string;
  isOfficial?: boolean;
  isDiscourseOwned?: boolean;
  label?: string | null;
  commitHash?: string | null;
  commitUrl?: string | null;
  metaUrl?: string | null;
  authors?: string | null;
  extras?: Record<string, unknown>;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface AdminPlugin extends AdminPluginFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class AdminPlugin {
  static create(args: Partial<AdminPluginPayload> = {}): AdminPlugin {
    return new AdminPlugin(args);
  }

  @tracked enabled: boolean | undefined;

  constructor(args: Partial<AdminPluginPayload> = {}) {
    Object.keys(args).forEach((key) => {
      (this as unknown as Record<string, unknown>)[snakeCaseToCamelCase(key)] =
        args[key as keyof AdminPluginPayload];
    });
  }

  get useNewShowRoute(): boolean | undefined {
    return this.adminRoute?.use_new_show_route;
  }

  get snakeCaseName(): string {
    return this.name.replaceAll("-", "_");
  }

  get dasherizedName(): string {
    return dasherize(this.name);
  }

  get translatedCategoryName(): string | undefined {
    // We do this because the site setting list is grouped by category,
    // with plugins that have their root site setting key defined as `plugins:`
    // being grouped under the generic "plugins" category.
    //
    // If a site setting has defined a proper root key and translated category name,
    // we can use that instead to go directly to the setting category.
    //
    // Over time, no plugins should be missing this data.
    return I18n.lookup(`admin.site_settings.categories.${this.snakeCaseName}`);
  }

  get settingCategoryName(): string {
    if (this.translatedCategoryName) {
      return this.snakeCaseName;
    }

    return "plugins";
  }

  @cached
  get nameTitleized(): string {
    return stripDiscoursePrefix(
      this.translatedCategoryName || this.humanizedName
    );
  }

  @cached
  get nameTitleizedLower(): string {
    return this.nameTitleized.toLowerCase();
  }

  get author(): string {
    if (this.isOfficial || this.isDiscourseOwned) {
      return i18n("admin.plugins.author", { author: "Discourse" });
    }

    return i18n("admin.plugins.author", { author: this.authors });
  }

  get linkUrl(): string | undefined {
    return this.metaUrl || this.url;
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "admin-plugin": AdminPlugin;
  }

  interface ModelCreateAttrsRegistry {
    "admin-plugin": Partial<AdminPluginPayload>;
  }
}
