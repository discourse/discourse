import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import i18n from "discourse/helpers/i18n";
import icon from "discourse/helpers/d-icon";

export default class ChatChannelChooserHeader extends ComboBoxSelectBoxHeaderComponent {<template><div class="select-kit-header-wrapper">
  {{#if this.selectedContent}}
    <ChannelTitle @channel={{this.selectedContent}} />
  {{else}}
    {{i18n "chat.incoming_webhooks.channel_placeholder"}}
  {{/if}}

  {{icon this.caretIcon class="caret-icon"}}
</div></template>}
