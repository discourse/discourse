import { service } from "discourse/lib/service";
import Modifier from "ember-modifier";
import AdminSearchDataSourceService from "discourse/admin/services/admin-search-data-source";

// Rewrites the href of server-rendered `{{setting:foo}}` links so they point at
// the setting's actual config page instead of the generic all-settings page.
// The server can only emit the fallback URL because the area/category -> page
// mapping lives in the client nav map; the metadata it knows is passed through
// data attributes on the anchor.
export default class LinkifySettingLinks extends Modifier {
  @service(() => AdminSearchDataSourceService) adminSearchDataSource;

  modify(element, [description]) {
    if (!description) {
      return;
    }

    element
      .querySelectorAll("a.site-setting-link[data-setting-name]")
      .forEach((anchor) => {
        const url = this.adminSearchDataSource.urlForSetting({
          setting: anchor.dataset.settingName,
          primaryArea: anchor.dataset.settingArea,
          category: anchor.dataset.settingCategory,
          plugin: anchor.dataset.settingPlugin,
        });

        if (url) {
          anchor.setAttribute("href", url);
        }
      });
  }
}
