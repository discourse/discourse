import Route from "@ember/routing/route";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class AdminSiteTextIndexRoute extends Route {
  queryParams = {
    q: { replace: true },
    overridden: { replace: true },
    outdated: { replace: true },
    untranslated: { replace: true },
    locale: { replace: true },
  };

  setupController(controller) {
    controller.resetSearch();
  }
}
