import Component from "@glimmer/component";
import CloseDrawerButton from "./close-drawer-button";
import CloseThreadButton from "./close-thread-button";
import CloseThreadsButton from "./close-threads-button";
import FullPageButton from "./full-page-button";
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
      {{yield}}
    </nav>
  </template>
}
