import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import EmptyState from "discourse/components/empty-state";
import FilterInput from "discourse/components/filter-input";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
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

  get currentTab() {
    return this.args.currentTab ?? ALL;
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
      return [...TABS].removeObject(ARCHIVED);
    }
  }

  @action
  showChatNewMessageModal() {
    this.modal.show(ChatModalNewMessage);
  }

  @action
  setFilter(event) {
    this.filter = event.target.value;
    discourseDebounce(this.debouncedLoad, INPUT_DELAY);
  }

  @action
  debouncedLoad() {
    this.channelsCollection.load({ limit: 10 });
  }

  @action
  focusFilterInput(input) {
    schedule("afterRender", () => input?.focus());
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

        <FilterInput
          {{didInsert this.focusFilterInput}}
          @filterAction={{this.setFilter}}
          @icons={{hash right="magnifying-glass"}}
          placeholder={{i18n "chat.browse.filter_input_placeholder"}}
        />
      </div>

      <div class="chat-browse-view__content_wrapper">
        <div class="chat-browse-view__content">
          <List
            @collection={{this.channelsCollection}}
            class="chat-browse-view__cards"
            as |list|
          >
            <list.Item as |channel|>
              <ChatChannelCard @channel={{channel}} />
            </list.Item>

            <list.EmptyState>
              <EmptyState
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
