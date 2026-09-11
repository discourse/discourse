import ChatComposer from "../chat-composer.gjs";
import ChatComposerMessageDetails from "../chat-composer-message-details.gjs";
import ChatHeaderIcon from "../chat-header-icon.gjs";
import ChatMessage from "../chat-message.gjs";
import ChatModalArchiveChannel from "../chat-modal-archive-channel.gjs";
import ChatModalCreateChannel from "../chat-modal-create-channel.gjs";
import ChatModalDeleteChannel from "../chat-modal-delete-channel.gjs";
import ChatModalEditChannelDescription from "../chat-modal-edit-channel-description.gjs";
import ChatModalEditChannelName from "../chat-modal-edit-channel-name.gjs";
import ChatModalMoveMessageToChannel from "../chat-modal-move-message-to-channel.gjs";
import ChatModalNewMessage from "../chat-modal-new-message.gjs";
import ChatModalThreadSettings from "../chat-modal-thread-settings.gjs";
import ChatModalToggleChannelStatus from "../chat-modal-toggle-channel-status.gjs";
import ChatThreadListItem from "../chat-thread-list-item.gjs";

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
