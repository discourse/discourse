import Component from "@glimmer/component";
import { service } from "@ember/service";
import ChatChannelListFilterToggle from "../../chat-channel-list-filter-toggle.gjs";
import ChatChannelListOptionsButton from "../../chat-channel-list-options-button.gjs";

/**
 * Mobile navbar action that opens the shared channel list menu
 * (filter/sort/browse/create) for a section. On mobile the channel lists hide
 * their in-list section divider (the cover sidebar and desktop drawer are not
 * available), so the options menu lives in the route navbar instead.
 */
export default class ChatNavbarChannelListOptionsButton extends Component {
  @service site;

  get showButton() {
    return this.site.mobileView;
  }

  <template>
    {{#if this.showButton}}
      <ChatChannelListFilterToggle @section={{@section}} />
      <ChatChannelListOptionsButton @section={{@section}} />
    {{/if}}
  </template>
}
