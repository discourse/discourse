import Route from "@ember/routing/route";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { inject as service } from "@ember/service";

@disableImplicitInjections
export default class AdminSiteTextIndexRoute extends Route {
  @service siteSettings;
  @service store;

  queryParams = {
    q: { replace: true },
    overridden: { replace: true },
    outdated: { replace: true },
    locale: { replace: true },
  };

  model(params) {
    return this.store.find("site-text", {
      q: params.q,
      overridden: params.overridden ?? false,
      outdated: params.outdated ?? false,
      locale: params.locale ?? this.siteSettings.default_locale,
    });
  }
}
