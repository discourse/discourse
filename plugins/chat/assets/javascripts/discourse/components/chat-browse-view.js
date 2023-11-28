import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import ChatModalCreateChannel from "discourse/plugins/chat/discourse/components/chat/modal/create-channel";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";

const TABS = ["all", "open", "closed", "archived"];

export default class ChatBrowseView extends Component {
  @service chatApi;
  @service modal;

  tagName = "";

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (!this.channelsCollection) {
      this.set("channelsCollection", this.chatApi.channels());
    }

    this.channelsCollection.load({
      filter: this.filter,
      status: this.status,
    });
  }

  @computed("siteSettings.chat_allow_archiving_channels")
  get tabs() {
    if (this.siteSettings.chat_allow_archiving_channels) {
      return TABS;
    } else {
      return [...TABS].removeObject("archived");
    }
  }

  @action
  showChatNewMessageModal() {
    this.modal.show(ChatModalNewMessage);
  }

  @action
  onScroll() {
    discourseDebounce(
      this,
      this.channelsCollection.load,
      { filter: this.filter, status: this.status },
      INPUT_DELAY
    );
  }

  @action
  debouncedFiltering(event) {
    this.set("channelsCollection", this.chatApi.channels());

    discourseDebounce(
      this,
      this.channelsCollection.load,
      { filter: event.target.value, status: this.status },
      INPUT_DELAY
    );
  }

  @action
  createChannel() {
    this.modal.show(ChatModalCreateChannel);
  }

  @action
  focusFilterInput(input) {
    schedule("afterRender", () => input?.focus());
  }
}
