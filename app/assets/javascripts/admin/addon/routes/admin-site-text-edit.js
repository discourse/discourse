import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminSiteTextEditRoute extends Route {
  queryParams = {
    locale: { replace: true },
  };

  model(params) {
    return ajax(
      `/admin/customize/site_texts/${params.id}?locale=${params.locale}`
    ).then((result) => {
      return this.store.createRecord("site-text", result.site_text);
    });
  }

  setupController(controller, siteText) {
    const locales = JSON.parse(this.siteSettings.available_locales);

    const localeFullName = locales.find((locale) => {
      return locale.value === controller.locale;
    }).name;

    controller.setProperties({
      siteText,
      saved: false,
      localeFullName,
    });
  }
}
