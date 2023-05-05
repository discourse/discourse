import Component from "@glimmer/component";
import { action } from "@ember/object";
import { addPreloadLink } from "../lib/chat-preload-link";

export default class ChatMessageThreadIndicator extends Component {
  @action
  prefetchThread() {
    const channel = this.args.message.channel;
    const thread = this.args.message.thread;

    addPreloadLink(
      `/chat/api/channels/${channel.id}/threads/${thread.id}.json`
    );
    addPreloadLink(
      `/chat/${channel.id}/messages.json?page_size=50&thread_id=${thread.id}`
    );
  }
}
