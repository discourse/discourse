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
  members = null;

  didInsertElement() {
    this._super(...arguments);

    if (!this.channel) {
      return;
    }

    this._focusSearch();
    this.set("members", this.chatApi.listChannelMemberships(this.channel.id));
    this.members.load();

    this.appEvents.on("chat:refresh-channel-members", this, "onFilterMembers");
  }

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("chat:refresh-channel-members", this, "onFilterMembers");
  }

  @action
  onFilterMembers(username) {
    this.set("filter", username);
    this.set("members", this.chatApi.listChannelMemberships(this.channel.id));

    discourseDebounce(
      this,
      this.members.load,
      { username: this.filter },
      INPUT_DELAY
    );
  }

  @action
  load() {
    discourseDebounce(this, this.members.load, INPUT_DELAY);
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
