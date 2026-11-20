import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";
import MessageCreator from "discourse/plugins/chat/discourse/components/chat/message-creator";
import { MODES } from "discourse/plugins/chat/discourse/components/chat/message-creator/constants";
import ChatUserInfo from "discourse/plugins/chat/discourse/components/chat-user-info";

export default class ChatRouteChannelMembers extends Component {
  @service chatApi;
  @service chatGuardian;
  @service currentUser;
  @service loadingSlider;

  @tracked filter = "";
  @tracked updatedAt = Date.now();
  @tracked showAddMembers = false;

  addMemberLabel = i18n("chat.members_view.add_member");
  filterPlaceholder = i18n("chat.members_view.filter_placeholder");
  noMembershipsFoundLabel = i18n("chat.channel.no_memberships_found");
  noMembershipsLabel = i18n("chat.channel.no_memberships");

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
    return (
      this.members.fetchedOnce &&
      !this.members.loading &&
      this.members.length === 0
    );
  }

  @cached
  get members() {
    const params = {};
    if (this.filter?.length) {
      params.username = this.filter;
    }
    manuallyTrack(this.updatedAt);

    return this.chatApi.listChannelMemberships(this.args.channel.id, params);
  }

  get addMembersMode() {
    return MODES.add_members;
  }

  get canAddMembers() {
    if (
      !this.args.channel.isDirectMessageChannel ||
      !this.chatGuardian.canUseGroupChat()
    ) {
      return false;
    }

    return (
      this.args.channel.chatable.group ||
      !this.args.channel.lastMessage?.message
    );
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
  async removeMember(user) {
    await this.chatApi.removeMemberFromChannel(this.args.channel.id, user.id);
    this.updatedAt = Date.now();
    this.load();
  }

  @bind
  canRemoveMember(user) {
    return (
      this.args.channel.canRemoveMembers && user.id !== this.currentUser.id
    );
  }

  async debouncedLoad() {
    this.loadingSlider.transitionStarted();
    await this.members.load({ limit: 20 }).catch(() => {});
    this.loadingSlider.transitionEnded();
  }

  <template>
    <div class="c-channel-members">
      <h1 class="sr-only">{{i18n
          "chat.channel_info.members_title"
          channel=@channel.title
        }}</h1>

      {{#if this.showAddMembers}}
        <MessageCreator
          @channel={{@channel}}
          @mode={{this.addMembersMode}}
          @onCancel={{this.hideAddMember}}
          @onClose={{this.hideAddMember}}
        />
      {{else}}
        <div class="c-channel-members__controls">
          <DFilterInput
            placeholder={{this.filterPlaceholder}}
            @containerClass="c-channel-members__filter"
            @filterAction={{this.mutFilter}}
            @icons={{hash right="magnifying-glass"}}
            {{dAutoFocus}}
          />

          {{#if this.canAddMembers}}
            <DButton
              class="btn-default c-channel-members__add-member"
              @action={{this.addMember}}
              @icon="plus"
              @translatedLabel={{this.addMemberLabel}}
            />
          {{/if}}
        </div>

        <ul class="c-channel-members__list" {{this.fill}}>
          {{#each this.members as |membership|}}
            <li class="c-channel-members__list-item">
              <ChatUserInfo
                @avatarSize="tiny"
                @interactive={{true}}
                @showStatus={{true}}
                @showStatusDescription={{true}}
                @user={{membership.user}}
              />
              {{#if (this.canRemoveMember membership.user)}}
                <DButton
                  class="btn-default btn-small remove-member"
                  @action={{fn this.removeMember membership.user}}
                  @label="chat.channel_info.remove_member"
                />
              {{/if}}
            </li>
          {{/each}}
        </ul>

        {{#if this.noResults}}
          <div class="c-channel-members__no-results alert alert-info">
            {{this.noMembershipsFoundLabel}}
          </div>
        {{/if}}

        <div {{this.loadMore}}>
          <br />
        </div>
      {{/if}}
    </div>
  </template>
}
