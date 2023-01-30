import Component from "@ember/component";
import { inject as service } from "@ember/service";

export default class ChatChannelAboutView extends Component {
  @service chat;
  tagName = "";
  channel = null;
  onEditChatChannelName = null;
  onEditChatChannelDescription = null;
  isLoading = false;
}
