import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class ChatChannelChooserHeader extends ComboBoxSelectBoxHeaderComponent {
  <template>
    <div class="select-kit-header-wrapper">
      {{#if this.selectedContent}}
        <ChannelTitle @channel={{this.selectedContent}} />
      {{else}}
        {{i18n "chat.incoming_webhooks.channel_placeholder"}}
      {{/if}}

      {{icon this.caretIcon class="caret-icon"}}
    </div>
  </template>
}
