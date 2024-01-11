import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import CloseDrawerButton from "./close-drawer-button";
import CloseThreadButton from "./close-thread-button";
import CloseThreadsButton from "./close-threads-button";
import FullPageButton from "./full-page-button";
import BrowseChannelsButton from "./browse-channels-button";
import NewDirectMessageButton from "./new-direct-message-button";
import NewChannelButton from "./new-channel-button";
import OpenDrawerButton from "./open-drawer-button";
import ThreadSettingsButton from "./thread-settings-button";
import ThreadTrackingDropdown from "./thread-tracking-dropdown";
import ThreadsListButton from "./threads-list-button";
import ToggleDrawerButton from "./toggle-drawer-button";

export default class ChatNavbarActions extends Component {
  get openDrawerButtonComponent() {
    return OpenDrawerButton;
  }

  get browseChannelsButtonComponent() {
    return BrowseChannelsButton;
  }

  get newDirectMessageButtonComponent() {
    return NewDirectMessageButton;
  }

  get newChannelButtonComponent() {
    return NewChannelButton;
  }

  get threadTrackingDropdownComponent() {
    return ThreadTrackingDropdown;
  }

  get closeThreadButtonComponent() {
    return CloseThreadButton;
  }

  get closeThreadsButtonComponent() {
    return CloseThreadsButton;
  }

  get threadSettingsButtonComponent() {
    return ThreadSettingsButton;
  }

  get threadsListButtonComponent() {
    return ThreadsListButton;
  }

  get closeDrawerButtonComponent() {
    return CloseDrawerButton;
  }

  get toggleDrawerButtonComponent() {
    return ToggleDrawerButton;
  }

  get chatNavbarFullPageButtonComponent() {
    return FullPageButton;
  }

  <template>
    <nav class="c-navbar__actions">
      {{yield
        (hash
          OpenDrawerButton=this.openDrawerButtonComponent
          BrowseChannelsButton=this.browseChannelsButtonComponent
          NewDirectMessageButton=this.newDirectMessageButtonComponent
          NewChannelButton=this.newChannelButtonComponent
          ThreadTrackingDropdown=this.threadTrackingDropdownComponent
          CloseThreadButton=this.closeThreadButtonComponent
          CloseThreadsButton=this.closeThreadsButtonComponent
          ThreadSettingsButton=this.threadSettingsButtonComponent
          ThreadsListButton=this.threadsListButtonComponent
          CloseDrawerButton=this.closeDrawerButtonComponent
          ToggleDrawerButton=this.toggleDrawerButtonComponent
          FullPageButton=this.chatNavbarFullPageButtonComponent
        )
      }}
    </nav>
  </template>
}
