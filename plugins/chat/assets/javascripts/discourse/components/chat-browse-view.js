import { INPUT_DELAY } from "discourse-common/config/environment";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import ChatApi from "discourse/plugins/chat/discourse/lib/chat-api";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";

const TABS = ["all", "open", "closed", "archived"];
const PER_PAGE = 20;

export default class ChatBrowseView extends Component {
  @service router;
  @tracked isLoading = false;
  @tracked channels = [];
  tagName = "";

  offset = 0;
  canLoadMore = true;

  didReceiveAttrs() {
    this._super(...arguments);

    this.channels = [];
    this.canLoadMore = true;
    this.offset = 0;
    this.fetchChannels();
  }

  async fetchChannels(params) {
    if (this.isLoading || !this.canLoadMore) {
      return;
    }

    this.isLoading = true;

    try {
      const results = await ChatApi.chatChannels({
        limit: PER_PAGE,
        offset: this.offset,
        status: this.status,
        filter: this.filter,
        ...params,
      });

      if (results.length) {
        this.channels.pushObjects(results);
      }

      if (results.length < PER_PAGE) {
        this.canLoadMore = false;
      }
    } finally {
      this.offset = this.offset + PER_PAGE;
      this.isLoading = false;
    }
  }

  @computed("siteSettings.chat_allow_archiving_channels")
  get tabs() {
    if (this.siteSettings.chat_allow_archiving_channels) {
      return TABS;
    } else {
      return [...TABS].removeObject("archived");
    }
  }

  get chatProgressBarContainer() {
    return document.querySelector("#chat-progress-bar-container");
  }

  @action
  onScroll() {
    if (this.isLoading) {
      return;
    }

    discourseDebounce(this, this.fetchChannels, INPUT_DELAY);
  }

  @action
  debouncedFiltering(event) {
    discourseDebounce(
      this,
      this.filterChannels,
      event.target.value,
      INPUT_DELAY
    );
  }

  @action
  createChannel() {
    showModal("create-channel");
  }

  @action
  focusFilterInput(input) {
    schedule("afterRender", () => input?.focus());
  }

  @bind
  filterChannels(filter) {
    this.canLoadMore = true;
    this.filter = filter;
    this.channels = [];
    this.offset = 0;

    this.fetchChannels();
  }
}
