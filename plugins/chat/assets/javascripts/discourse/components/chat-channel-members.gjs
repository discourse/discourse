import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { INPUT_DELAY } from "discourse-common/config/environment";
import icon from "discourse-common/helpers/d-icon";
import discourseDebounce from "discourse-common/lib/debounce";
import I18n from "discourse-i18n";
import MessageCreator from "discourse/plugins/chat/discourse/components/chat/message-creator";
import ChatUserInfo from "discourse/plugins/chat/discourse/components/chat-user-info";
import DcFilterInput from "discourse/plugins/chat/discourse/components/dc-filter-input";
import { MODES } from "./chat/message-creator/constants";

export default class ChatChannelMembers extends Component {
  @service appEvents;
  @service chatApi;
  @service modal;
  @service loadingSlider;

  @tracked filter = "";
  @tracked showAddMembers = false;

  addMemberLabel = I18n.t("chat.members_view.add_member");
  filterPlaceholder = I18n.t("chat.members_view.filter_placeholder");
  noMembershipsFoundLabel = I18n.t("chat.channel.no_memberships_found");
  noMembershipsLabel = I18n.t("chat.channel.no_memberships");

  focusInput = modifier((element) => {
    schedule("afterRender", () => {
      element.focus();
    });
  });

  onEnter = modifier((element, [callback]) => {
    const handler = (event) => {
      if (event.key !== "Enter") {
        return;
      }

      callback(event);
    };

    element.addEventListener("keydown", handler);

    return () => {
      element.removeEventListener("keydown", handler);
    };
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

  @action
  addMember() {
    this.showAddMembers = true;
  }

  @action
  hideAddMember() {
    this.showAddMembers = false;
  }

  @action
  openMemberCard(user, event) {
    event.preventDefault();
    DiscourseURL.routeTo(userPath(user.username_lower));
  }

  async debouncedLoad() {
    this.loadingSlider.transitionStarted();
    await this.members.load({ limit: 20 });
    this.loadingSlider.transitionEnded();
  }

  get addMembersMode() {
    return MODES.add_members;
  }

  <template>
    {{#if this.showAddMembers}}
      <MessageCreator
        @mode={{this.addMembersMode}}
        @channel={{@channel}}
        @onClose={{this.hideAddMember}}
        @onCancel={{this.hideAddMember}}
      />
    {{else}}
      <div class="chat-channel-members">
        <DcFilterInput
          @class="chat-channel-members__filter"
          @filterAction={{this.mutFilter}}
          @icons={{hash right="search"}}
          placeholder={{this.filterPlaceholder}}
          {{this.focusInput}}
        />

        <ul class="chat-channel-members__list" {{this.fill}}>
          {{#if @channel.chatable.group}}
            <li
              class="chat-channel-members__list-item -add-member"
              role="button"
              {{on "click" this.addMember}}
              {{this.onEnter this.addMember}}
              tabindex="0"
            >
              {{icon "plus"}}
              <span>{{this.addMemberLabel}}</span>
            </li>
          {{/if}}
          {{#each this.members as |membership|}}
            <li
              class="chat-channel-members__list-item -member"
              {{on "click" (fn this.openMemberCard membership.user)}}
              {{this.onEnter (fn this.openMemberCard membership.user)}}
              tabindex="0"
            >
              <ChatUserInfo
                @user={{membership.user}}
                @avatarSize="tiny"
                @interactive={{false}}
              />
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
      </div>
    {{/if}}
  </template>
}
