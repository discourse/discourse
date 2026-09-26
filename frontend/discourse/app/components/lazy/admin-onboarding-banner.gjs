import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import CurrentUserService from "discourse/services/current-user";
import SiteSettingsService from "discourse/services/site-settings";

let load;

export default class LazyAdminOnboardingBanner extends Component {
  @service(() => CurrentUserService) currentUser;
  @service(() => SiteSettingsService) siteSettings;

  get component() {
    return (load ??= import("discourse/components/admin-onboarding/banner"));
  }

  <template>
    {{#if this.siteSettings.enable_site_owner_onboarding}}
      {{#if this.currentUser.admin}}
        <DAsyncContent @asyncData={{this.component}}>
          <:loading></:loading>
          <:content as |module|><module.default /></:content>
        </DAsyncContent>
      {{/if}}
    {{/if}}
  </template>
}
