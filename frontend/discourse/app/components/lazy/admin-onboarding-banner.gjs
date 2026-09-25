import Component from "@glimmer/component";
import { service } from "@ember/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyAdminOnboardingBanner extends Component {
  @service currentUser;
  @service siteSettings;

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
