import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatThreadList extends Component {
  @service chat;

  @tracked threads;
  @tracked loading = true;

  @action
  loadThreads() {
    this.loading = true;
    this.channel.threadsManager
      .index(this.channel.id)
      .then((result) => {
        if (result.meta.channel_id === this.channel.id) {
          this.threads = result.threads;
        }
      })
      .finally(() => {
        this.loading = false;
      });
  }

  @action
  teardown() {
    this.loading = true;
    this.threads = null;
  }

  get channel() {
    return this.chat.activeChannel;
  }
}
