import { INPUT_DELAY } from "discourse-common/config/environment";
import Component from "@ember/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";

export default class ChatChannelMembersView extends Component {
  @service chatApi;

  tagName = "";
  channel = null;
  isSearchFocused = false;
  onlineUsers = null;
  filter = null;
  inputSelector = "channel-members-view__search-input";
  membershipsCollection = null;

  didInsertElement() {
    this._super(...arguments);

    if (!this.channel || this.channel.isDraft) {
      return;
    }

    this._focusSearch();
    this.set(
      "membershipsCollection",
      this.chatApi.listChannelMemberships(this.channel.id)
    );
    this.membershipsCollection.load();

    this.appEvents.on("chat:refresh-channel-members", this, "onFilterMembers");
  }

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("chat:refresh-channel-members", this, "onFilterMembers");
  }

  get chatProgressBarContainer() {
    return document.querySelector("#chat-progress-bar-container");
  }

  @action
  onFilterMembers(username) {
    this.set("filter", username);

    discourseDebounce(
      this,
      this.membershipsCollection.load,
      { username: this.filter },
      INPUT_DELAY
    );
  }

  @action
  loadMore() {
    discourseDebounce(this, this.membershipsCollection.loadMore, INPUT_DELAY);
  }

  _focusSearch() {
    if (this.capabilities.isIpadOS || this.site.mobileView) {
      return;
    }

    schedule("afterRender", () => {
      document.getElementsByClassName(this.inputSelector)[0]?.focus();
    });
  }
}
