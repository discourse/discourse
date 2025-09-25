import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class AdminSiteTextIndexRoute extends Route {
  @service siteSettings;
  @service store;

  queryParams = {
    q: { replace: true },
    overridden: { replace: true },
    outdated: { replace: true },
    untranslated: { replace: true },
    locale: { replace: true },
  };

  model(params) {
    return this.store.find("site-text", {
      q: params.q,
      overridden: params.overridden ?? false,
      outdated: params.outdated ?? false,
      untranslated: params.untranslated ?? false,
      locale: params.locale ?? this.siteSettings.default_locale,
      only_selected_locale: params.onlySelectedLocale ?? false,
    });
  }
}
