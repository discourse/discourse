import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import FilterInput from "discourse/components/filter-input";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import DiscourseURL, { userPath } from "discourse/lib/url";
import autoFocus from "discourse/modifiers/auto-focus";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import MessageCreator from "discourse/plugins/chat/discourse/components/chat/message-creator";
import { MODES } from "discourse/plugins/chat/discourse/components/chat/message-creator/constants";
import ChatUserInfo from "discourse/plugins/chat/discourse/components/chat-user-info";

export default class ChatRouteChannelInfoMembers extends Component {
  @service appEvents;
  @service chatApi;
  @service modal;
  @service loadingSlider;
  @service site;

  @tracked filter = "";
  @tracked showAddMembers = false;

  addMemberLabel = i18n("chat.members_view.add_member");
  filterPlaceholder = i18n("chat.members_view.filter_placeholder");
  noMembershipsFoundLabel = i18n("chat.channel.no_memberships_found");
  noMembershipsLabel = i18n("chat.channel.no_memberships");

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
    <div class="c-routes --channel-info-members">
      {{#if this.site.mobileView}}
        <LinkTo
          class="c-back-button"
          @route="chat.channel.info.settings"
          @model={{@channel}}
        >
          {{icon "chevron-left"}}
          {{i18n "chat.members_view.back_to_settings"}}
        </LinkTo>
      {{/if}}
      {{#if this.showAddMembers}}
        <MessageCreator
          @mode={{this.addMembersMode}}
          @channel={{@channel}}
          @onClose={{this.hideAddMember}}
          @onCancel={{this.hideAddMember}}
        />
      {{else}}
        <div class="c-channel-members">
          <FilterInput
            {{autoFocus}}
            @filterAction={{this.mutFilter}}
            @icons={{hash right="magnifying-glass"}}
            @containerClass="c-channel-members__filter"
            placeholder={{this.filterPlaceholder}}
          />

          <ul class="c-channel-members__list" {{this.fill}}>
            {{#if @channel.chatable.group}}
              <li
                class="c-channel-members__list-item -add-member"
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
                class="c-channel-members__list-item -member"
                {{on "click" (fn this.openMemberCard membership.user)}}
                {{this.onEnter (fn this.openMemberCard membership.user)}}
                tabindex="0"
              >
                <ChatUserInfo
                  @user={{membership.user}}
                  @avatarSize="tiny"
                  @interactive={{false}}
                  @showStatus={{true}}
                  @showStatusDescription={{true}}
                />
              </li>
            {{else}}
              {{#if this.noResults}}
                <li
                  class="c-channel-members__list-item -no-results alert alert-info"
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
    </div>
  </template>
}
