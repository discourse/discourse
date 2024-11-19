import { cached, tracked } from "@glimmer/tracking";
import { capitalize, dasherize } from "@ember/string";
import { snakeCaseToCamelCase } from "discourse-common/lib/case-converter";
import I18n, { i18n } from "discourse-i18n";

export default class AdminPlugin {
  static create(args = {}) {
    return new AdminPlugin(args);
  }

  @tracked enabled;

  constructor(args = {}) {
    Object.keys(args).forEach((key) => {
      this[snakeCaseToCamelCase(key)] = args[key];
    });
  }

  get useNewShowRoute() {
    return this.adminRoute?.use_new_show_route;
  }

  get snakeCaseName() {
    return this.name.replaceAll("-", "_");
  }

  get dasherizedName() {
    return dasherize(this.name);
  }

  get translatedCategoryName() {
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

  get settingCategoryName() {
    if (this.translatedCategoryName) {
      return this.snakeCaseName;
    }

    return "plugins";
  }

  @cached
  get nameTitleized() {
    // The category name is better in a lot of cases, as it's a human-inputted
    // translation, and we can handle things like SAML instead of showing them
    // as Saml from discourse-saml. We can fall back to the programmatic version
    // though if needed.
    let name;
    if (this.translatedCategoryName) {
      name = this.translatedCategoryName;
    } else {
      name = this.name
        .split(/[-_]/)
        .map((word) => {
          return capitalize(word);
        })
        .join(" ");
    }

    // Cuts down on repetition.
    const discoursePrefix = "Discourse ";
    if (name.startsWith(discoursePrefix)) {
      name = name.slice(discoursePrefix.length);
    }

    return name;
  }

  @cached
  get nameTitleizedLower() {
    return this.nameTitleized.toLowerCase();
  }

  get author() {
    if (this.isOfficial || this.isDiscourseOwned) {
      return i18n("admin.plugins.author", { author: "Discourse" });
    }

    return i18n("admin.plugins.author", { author: this.authors });
  }

  get linkUrl() {
    return this.metaUrl || this.url;
  }
}
