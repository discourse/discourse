import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "discourse/lib/service";
import { trustHTML } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import DButton from "discourse/ui-kit/d-button";
import CurrentUserService from "discourse/services/current-user";

export default class DominatingTopicComposerMessage extends Component {
  @service(() => CurrentUserService) currentUser;

  <template>
    <ComposerTipCloseButton @action={{fn @closeMessage @message}} />
    <div class="composer-popup__content">

      {{trustHTML @message.body}}

      {{#if this.currentUser.can_invite_to_forum}}
        <DButton
          class="btn-primary"
          @action={{@shareModal}}
          @icon="link"
          @label="footer_nav.share"
        />
      {{/if}}
    </div>
  </template>
}
