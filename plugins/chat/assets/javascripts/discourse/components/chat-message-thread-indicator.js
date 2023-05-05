import Component from "@glimmer/component";
import { action } from "@ember/object";
import { addPreloadLink } from "../lib/chat-preload-link";
import { PAGE_SIZE } from "./chat-thread";

export default class ChatMessageThreadIndicator extends Component {
  @action
  preloadThread() {
    const channel = this.args.message.channel;
    const thread = this.args.message.thread;

    addPreloadLink(
      `/chat/api/channels/${channel.id}/threads/${thread.id}.json`,
      `thread-preload-${thread.id}`
    );
    addPreloadLink(
      `/chat/${channel.id}/messages.json?page_size=${PAGE_SIZE}&thread_id=${thread.id}`,
      `thread-preload-messages-${thread.id}`
    );
  }
}
