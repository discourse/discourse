import Component from "@ember/component";

export default class ChatChannelMetadata extends Component {
  tagName = "div";
  classNames = ["chat-channel-metadata"];
  channel = null;
  unreadIndicator = false;
}
