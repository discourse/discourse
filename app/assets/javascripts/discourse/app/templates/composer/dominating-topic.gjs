import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import DButton from "discourse/components/d-button";

export default RouteTemplate(
  <template>
    <ComposerTipCloseButton
      @action={{fn @controller.closeMessage @controller.message}}
    />

    {{htmlSafe @controller.message.body}}

    {{#if @controller.currentUser.can_invite_to_forum}}
      <DButton
        @label="footer_nav.share"
        @icon="link"
        @action={{@controller.shareModal}}
        class="btn-primary"
      />
    {{/if}}
  </template>
);
