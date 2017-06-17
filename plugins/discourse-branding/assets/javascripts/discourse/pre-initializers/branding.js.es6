import ApplicationRoute from 'discourse/routes/application';
import { siteTitle } from "discourse/plugins/branding/discourse/lib/computed";

export default {
  name: 'apply-branding',
  initialize() {
    if (Discourse.SiteSettings['branding_enabled']) {
      ApplicationRoute.reopen({
        siteTitle: siteTitle(),
      });
    }
  }
};
