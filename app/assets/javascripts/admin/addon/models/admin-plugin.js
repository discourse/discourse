import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class AdminPlugin {
  static create(args = {}) {
    return new AdminPlugin(args);
  }

  @tracked enabled;

  constructor(args = {}) {
    this.about = args.about;
    this.adminRoute = args.admin_route;
    this.commitHash = args.commit_hash;
    this.commitUrl = args.commit_url;
    this.enabled = args.enabled;
    this.enabledSetting = args.enabled_setting;
    this.hasSettings = args.has_settings;
    this.id = args.id;
    this.isOfficial = args.is_official;
    this.name = args.name;
    this.url = args.url;
    this.version = args.version;
  }

  get settingCategoryName() {
    const snakeCaseName = this.name.replaceAll("-", "_");

    // We do this because the site setting list is grouped by category,
    // with plugins that have their root site setting key defined as `plugins:`
    // being grouped under the generic "plugins" category.
    //
    // If a site setting has defined a proper root key and translated category name,
    // we can use that instead to go directly to the setting category.
    //
    // Over time, no plugins should be missing this data.
    const translationAttempt = I18n.lookup(
      `admin.site_settings.categories.${snakeCaseName}`
    );
    if (translationAttempt) {
      return snakeCaseName;
    }

    return "plugins";
  }
}
