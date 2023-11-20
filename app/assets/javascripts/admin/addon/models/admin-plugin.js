import { tracked } from "@glimmer/tracking";
import { capitalize } from "@ember/string";
import I18n from "discourse-i18n";

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
    this.isDiscourseOwned = args.is_discourse_owned;
    this.isExperimental = args.is_experimental;
    this.name = args.name;
    this.url = args.url;
    this.version = args.version;
    this.metaUrl = args.meta_url;
    this.authors = args.authors;
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

  get nameTitleized() {
    return this.name
      .split("-")
      .map((word) => {
        return capitalize(word);
      })
      .join(" ");
  }

  get author() {
    if (this.isOfficial || this.isDiscourseOwned) {
      return I18n.t("admin.plugins.author", { author: "Discourse" });
    }

    return I18n.t("admin.plugins.author", { author: this.authors });
  }

  get linkUrl() {
    return this.metaUrl || this.url;
  }
}
