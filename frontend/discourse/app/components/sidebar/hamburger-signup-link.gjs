import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import SectionLinkButton from "./section-link-button";

export default class HamburgerSignupLink extends Component {
  @service currentUser;
  @service site;
  @service header;

  @controller application;

  get shouldRender() {
    return (
      !this.currentUser &&
      this.application.canSignUp &&
      this.site.mobileView &&
      !this.header.headerButtonsHidden.includes("signup")
    );
  }

  <template>
    {{#if this.shouldRender}}
      <SectionLinkButton
        @action={{@showCreateAccount}}
        @icon="user"
        @text={{i18n "sign_up"}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />
    {{/if}}
  </template>
}
