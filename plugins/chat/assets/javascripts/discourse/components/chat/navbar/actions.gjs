import { hash } from "@ember/helper";
import BrowseChannelsButton from "./browse-channels-button";
import CloseDrawerButton from "./close-drawer-button";
import CloseThreadButton from "./close-thread-button";
import CloseThreadsButton from "./close-threads-button";
import FullPageButton from "./full-page-button";
import NewChannelButton from "./new-channel-button";
import NewDirectMessageButton from "./new-direct-message-button";
import OpenDrawerButton from "./open-drawer-button";
import ThreadSettingsButton from "./thread-settings-button";
import ThreadTrackingDropdown from "./thread-tracking-dropdown";
import ThreadsListButton from "./threads-list-button";
import ToggleDrawerButton from "./toggle-drawer-button";

const ChatNavbarActions = <template>
  <nav class="c-navbar__actions">
    {{yield
      (hash
        OpenDrawerButton=OpenDrawerButton
        BrowseChannelsButton=BrowseChannelsButton
        NewDirectMessageButton=NewDirectMessageButton
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
</template>;

export default ChatNavbarActions;
