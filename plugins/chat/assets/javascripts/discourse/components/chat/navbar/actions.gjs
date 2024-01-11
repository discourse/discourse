import Component from "@glimmer/component";
import { hash } from "@ember/helper";
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
  <template>
    <nav class="c-navbar__actions">
      {{yield
        (hash
          OpenDrawerButton=OpenDrawerButton
          NewChannelButton=NewChannelButton
          ThreadTrackingDropdown=ThreadTrackingDropdown
          CloseThreadButton=CloseThreadButton
          CloseThreadsButton=CloseThreadsButton
          ThreadSettingsButton=ThreadSettingsButton
          ThreadsListButton=ThreadsListButton
          CloseDrawerButton=CloseDrawerButton
          ToggleDrawerButton=ToggleDrawerButton
          FullPageButton=FullPageButton
        )
      }}
    </nav>
  </template>
}
