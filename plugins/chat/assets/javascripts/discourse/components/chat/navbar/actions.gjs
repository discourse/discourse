import { hash } from "@ember/helper";
import CloseDrawerButton from "./close-drawer-button.gjs";
import ClosePinsButton from "./close-pins-button.gjs";
import CloseThreadButton from "./close-thread-button.gjs";
import CloseThreadsButton from "./close-threads-button.gjs";
import Filter from "./filter.gjs";
import FullPageButton from "./full-page-button.gjs";
import NewChannelButton from "./new-channel-button.gjs";
import OpenDrawerButton from "./open-drawer-button.gjs";
import PinnedMessagesButton from "./pinned-messages-button.gjs";
import ThreadSettingsButton from "./thread-settings-button.gjs";
import ThreadTrackingDropdown from "./thread-tracking-dropdown.gjs";
import ThreadsListButton from "./threads-list-button.gjs";
import ToggleDrawerButton from "./toggle-drawer-button.gjs";

const ChatNavbarActions = <template>
  <nav class="c-navbar__actions">
    {{yield
      (hash
        OpenDrawerButton=OpenDrawerButton
        NewChannelButton=NewChannelButton
        ThreadTrackingDropdown=ThreadTrackingDropdown
        CloseThreadButton=CloseThreadButton
        CloseThreadsButton=CloseThreadsButton
        ClosePinsButton=ClosePinsButton
        ThreadSettingsButton=ThreadSettingsButton
        ThreadsListButton=ThreadsListButton
        PinnedMessagesButton=PinnedMessagesButton
        CloseDrawerButton=CloseDrawerButton
        ToggleDrawerButton=ToggleDrawerButton
        FullPageButton=FullPageButton
        Filter=Filter
      )
    }}
  </nav>
</template>;

export default ChatNavbarActions;
