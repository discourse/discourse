import ChatComposer from "../chat-composer";
import ChatComposerMessageDetails from "../chat-composer-message-details";
import ChatHeaderIcon from "../chat-header-icon";
import ChatMessage from "../chat-message";
import ChatModalArchiveChannel from "../chat-modal-archive-channel";
import ChatModalCreateChannel from "../chat-modal-create-channel";
import ChatModalDeleteChannel from "../chat-modal-delete-channel";
import ChatModalEditChannelDescription from "../chat-modal-edit-channel-description";
import ChatModalEditChannelName from "../chat-modal-edit-channel-name";
import ChatModalMoveMessageToChannel from "../chat-modal-move-message-to-channel";
import ChatModalNewMessage from "../chat-modal-new-message";
import ChatModalThreadSettings from "../chat-modal-thread-settings";
import ChatModalToggleChannelStatus from "../chat-modal-toggle-channel-status";
import ChatThreadListItem from "../chat-thread-list-item";

const ChatOrganism = <template>
  <ChatMessage />
  <ChatComposer />
  <ChatThreadListItem />
  <ChatComposerMessageDetails />
  <ChatHeaderIcon />

  <h2>Modals</h2>

  <ChatModalArchiveChannel />
  <ChatModalMoveMessageToChannel />
  <ChatModalDeleteChannel />
  <ChatModalEditChannelDescription />
  <ChatModalEditChannelName />
  <ChatModalThreadSettings />
  <ChatModalCreateChannel />
  <ChatModalToggleChannelStatus />
  <ChatModalNewMessage />
</template>;

export default ChatOrganism;
