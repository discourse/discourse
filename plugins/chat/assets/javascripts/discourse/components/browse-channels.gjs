import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { eq } from "discourse/truth-helpers";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import { i18n } from "discourse-i18n";
import List from "discourse/plugins/chat/discourse/components/chat/list";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatChannelCard from "discourse/plugins/chat/discourse/components/chat-channel-card";

const ARCHIVED = "archived";
const ALL = "all";
const OPEN = "open";
const CLOSED = "closed";
const TABS = [ALL, OPEN, CLOSED, ARCHIVED];

export default class BrowseChannels extends Component {
  @service chatApi;
  @service modal;
  @service siteSettings;

  @tracked filter = "";
  @tracked selectedJoinedFilter = "all";

  get currentTab() {
    return this.args.currentTab ?? ALL;
  }

  get joinedFilters() {
    return [
      { label: i18n("chat.browse.filter_joined_all"), value: "all" },
      { label: i18n("chat.browse.filter_joined_joined"), value: "joined" },
      {
        label: i18n("chat.browse.filter_joined_not_joined"),
        value: "not-joined",
      },
    ];
  }

  @cached
  get channelsCollection() {
    return this.chatApi.channels({
      filter: this.filter,
      status: this.currentTab,
    });
  }

  get tabs() {
    if (this.siteSettings.chat_allow_archiving_channels) {
      return TABS;
    } else {
      return TABS.filter((item) => item !== ARCHIVED);
    }
  }

  @action
  setJoinedFilter(value) {
    this.selectedJoinedFilter = value;
  }

  @action
  filterChannelsByJoined(listItems) {
    if (this.selectedJoinedFilter === "joined") {
      return listItems.filter((channel) => channel.isFollowing);
    } else if (this.selectedJoinedFilter === "not-joined") {
      return listItems.filter((channel) => !channel.isFollowing);
    } else {
      return listItems;
    }
  }

  @action
  showChatNewMessageModal() {
    this.modal.show(ChatModalNewMessage);
  }

  @action
  setFilter(event) {
    discourseDebounce(
      this,
      this.debouncedSetFilter,
      event.target.value,
      INPUT_DELAY
    );
  }

  @action
  debouncedSetFilter(value) {
    this.filter = value;
  }

  <template>
    <div class="chat-browse-view">
      <div class="chat-browse-view__actions">
        <nav>
          <ul class="nav-pills chat-browse-view__filters">
            {{#each this.tabs as |tab|}}
              <li class={{concat "chat-browse-view__filter -" tab}}>
                <LinkTo
                  @route={{concat "chat.browse." tab}}
                  class={{concat "chat-browse-view__filter-link -" tab}}
                  @current-when={{eq tab this.currentTab}}
                >
                  {{i18n (concat "chat.browse.filter_" tab)}}
                </LinkTo>
              </li>
            {{/each}}
          </ul>
        </nav>

        <DFilterControls
          @array={{this.channelsCollection.items}}
          @dropdownOptions={{this.joinedFilters}}
          @dropdownValue={{this.selectedJoinedFilter}}
          @inputPlaceholder={{i18n "chat.browse.filter_input_placeholder"}}
          @loading={{this.channelsCollection.loading}}
          @onDropdownFilterChange={{this.setJoinedFilter}}
          @onTextFilterChange={{this.setFilter}}
          @showNoResults={{false}}
          @showResetButton={{false}}
        />
      </div>

      <div class="chat-browse-view__content_wrapper">
        <div class="chat-browse-view__content">
          <List
            @collection={{this.channelsCollection}}
            @filterFn={{this.filterChannelsByJoined}}
            class="chat-browse-view__cards"
            as |list|
          >
            <list.Item as |channel|>
              <ChatChannelCard @channel={{channel}} />
            </list.Item>

            <list.EmptyState>
              <DEmptyState
                @title={{i18n "chat.empty_state.title"}}
                @body={{i18n "chat.empty_state.direct_message"}}
                @ctaLabel={{i18n "chat.empty_state.direct_message_cta"}}
                @ctaAction={{this.showChatNewMessageModal}}
              />
            </list.EmptyState>
          </List>
        </div>
      </div>
    </div>
  </template>
}
