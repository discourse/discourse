import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import DButton from "discourse/components/d-button";

export default class DominatingTopicComposerMessage extends Component {
  @service currentUser;

  <template>
    <ComposerTipCloseButton @action={{fn @closeMessage @message}} />

    {{htmlSafe @message.body}}

    {{#if this.currentUser.can_invite_to_forum}}
      <DButton
        @label="footer_nav.share"
        @icon="link"
        @action={{@shareModal}}
        class="btn-primary"
      />
    {{/if}}
  </template>
}
