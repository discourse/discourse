import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import { canNativeShare, nativeShare } from "discourse/lib/pwa-utils";
import i18n from "discourse-common/helpers/i18n";

export default class ShareOrCopyInviteLink extends Component {
  @service capabilities;

  @action
  async nativeShare() {
    await nativeShare(this.capabilities, { url: this.args.invite.link });
  }

  <template>
    <input
      name="invite-link"
      type="text"
      class="invite-link"
      value={{@invite.link}}
      readonly={{true}}
    />
    {{#if (canNativeShare this.capabilities)}}
      <DButton
        class="btn-primary"
        @icon="share"
        @translatedLabel={{i18n "user.invited.invite.share_link"}}
        @action={{this.nativeShare}}
      />
    {{else}}
      <CopyButton
        @selector="input.invite-link"
        @translatedLabel={{i18n "user.invited.invite.copy_link"}}
        @translatedLabelAfterCopy={{i18n "user.invited.invite.link_copied"}}
      />
    {{/if}}
  </template>
}
