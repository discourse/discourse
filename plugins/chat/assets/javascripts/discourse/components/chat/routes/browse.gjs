import Component from "@ember/component";
import { concat, hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import { INPUT_DELAY } from "discourse-common/config/environment";
import i18n from "discourse-common/helpers/i18n";
import discourseDebounce from "discourse-common/lib/debounce";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatChannelCard from "discourse/plugins/chat/discourse/components/chat-channel-card";
import DcFilterInput from "discourse/plugins/chat/discourse/components/dc-filter-input";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";

const TABS = ["all", "open", "closed", "archived"];

export default class ChatRoutesBrowse extends Component {
  @service chatApi;
  @service modal;

  channelsCollection = this.chatApi.channels();

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
      { filter: this.filter, status: this.args.status },
      INPUT_DELAY
    );
  }

  @action
  debouncedFiltering(event) {
    this.channelsCollection = this.chatApi.channels();

    discourseDebounce(
      this,
      this.channelsCollection.load,
      { filter: event.target.value, status: this.args.status },
      INPUT_DELAY
    );
  }

  @action
  focusFilterInput(input) {
    schedule("afterRender", () => input?.focus());
  }

  @action
  load(_, [status]) {
    this.channelsCollection.load({
      filter: this.filter,
      status,
    });
  }

  <template>
    <div
      class="c-routes-browse"
      {{didUpdate this.load @status}}
      {{didInsert this.load @status}}
    >
      <Navbar as |navbar|>
        <navbar.BackButton />
        <navbar.Title @title={{i18n "chat.browse.title"}} />

        <navbar.Actions as |action|>
          <action.NewChannelButton />
        </navbar.Actions>
      </Navbar>

      <div class="chat-browse-view">
        <div class="chat-browse-view__actions">
          <nav>
            <ul class="nav-pills chat-browse-view__filters">
              {{#each this.tabs as |tab|}}
                <li class={{concat "chat-browse-view__filter -" tab}}>
                  <LinkTo
                    @route={{concat "chat.browse." tab}}
                    class={{concat "chat-browse-view__filter-link -" tab}}
                  >
                    {{i18n (concat "chat.browse.filter_" tab)}}
                  </LinkTo>
                </li>
              {{/each}}
            </ul>
          </nav>

          <DcFilterInput
            {{didInsert this.focusFilterInput}}
            @filterAction={{this.debouncedFiltering}}
            @icons={{hash right="search"}}
            @containerClass="filter-input"
            placeholder={{i18n "chat.browse.filter_input_placeholder"}}
          />
        </div>

        {{#if
          (and
            this.channelsCollection.fetchedOnce
            (not this.channelsCollection.length)
          )
        }}
          <div class="empty-state">
            <span class="empty-state-title">{{i18n
                "chat.empty_state.title"
              }}</span>
            <div class="empty-state-body">
              <p>{{i18n "chat.empty_state.direct_message"}}</p>
              <DButton
                @action={{this.showChatNewMessageModal}}
                @label="chat.empty_state.direct_message_cta"
              />
            </div>
          </div>
        {{else if this.channelsCollection.length}}
          <LoadMore
            @selector=".chat-channel-card"
            @action={{this.channelsCollection.load}}
          >
            <div class="chat-browse-view__content_wrapper">
              <div class="chat-browse-view__content">
                <div class="chat-browse-view__cards">
                  {{#each this.channelsCollection as |channel|}}
                    <ChatChannelCard @channel={{channel}} />
                  {{/each}}
                </div>
              </div>
            </div>

            <ConditionalLoadingSpinner
              @condition={{this.channelsCollection.loading}}
            />
          </LoadMore>
        {{/if}}
      </div>
    </div>
  </template>
}
