import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import I18n from "discourse-i18n";
import gt from "truth-helpers/helpers/gt";
import ChatUserInfo from "discourse/plugins/chat/discourse/components/chat-user-info";
import DcFilterInput from "discourse/plugins/chat/discourse/components/dc-filter-input";

export default class ChatChannelMembers extends Component {
  @service chatApi;
  @service modal;
  @service loadingSlider;

  @tracked filter = "";

  filterPlaceholder = I18n.t("chat.members_view.filter_placeholder");
  noMembershipsFoundLabel = I18n.t("chat.channel.no_memberships_found");
  noMembershipsLabel = I18n.t("chat.channel.no_memberships");

  focusInput = modifier((element) => {
    schedule("afterRender", () => {
      element.focus();
    });
  });

  fill = modifier((element) => {
    this.resizeObserver = new ResizeObserver(() => {
      if (isElementInViewport(element)) {
        this.load();
      }
    });

    this.resizeObserver.observe(element);

    return () => {
      this.resizeObserver.disconnect();
    };
  });

  loadMore = modifier((element) => {
    this.intersectionObserver = new IntersectionObserver(this.load);
    this.intersectionObserver.observe(element);

    return () => {
      this.intersectionObserver.disconnect();
    };
  });

  get noResults() {
    return this.members.fetchedOnce && !this.members.loading;
  }

  @cached
  get members() {
    const params = {};
    if (this.filter?.length) {
      params.username = this.filter;
    }

    return this.chatApi.listChannelMemberships(this.args.channel.id, params);
  }

  @action
  load() {
    discourseDebounce(this, this.debouncedLoad, INPUT_DELAY);
  }

  @action
  mutFilter(event) {
    this.filter = event.target.value;
    this.load();
  }

  async debouncedLoad() {
    this.loadingSlider.transitionStarted();
    await this.members.load({ limit: 20 });
    this.loadingSlider.transitionEnded();
  }

  <template>
    <div class="chat-channel-members">
      <DcFilterInput
        @class="chat-channel-members__filter"
        @filterAction={{this.mutFilter}}
        @icons={{hash right="search"}}
        placeholder={{this.filterPlaceholder}}
        {{this.focusInput}}
      />

      {{#if (gt @channel.membershipsCount 0)}}
        <ul class="chat-channel-members__list" {{this.fill}}>
          {{#each this.members as |membership|}}
            <li class="chat-channel-members__list-item">
              <ChatUserInfo @user={{membership.user}} @avatarSize="tiny" />
            </li>
          {{else}}
            {{#if this.noResults}}
              <li
                class="chat-channel-members__list-item -no-results alert alert-info"
              >
                {{this.noMembershipsFoundLabel}}
              </li>
            {{/if}}
          {{/each}}
        </ul>

        <div {{this.loadMore}}>
          <br />
        </div>
      {{else}}
        <p class="alert alert-info">
          {{this.noMembershipsLabel}}
        </p>
      {{/if}}
    </div>
  </template>
}
