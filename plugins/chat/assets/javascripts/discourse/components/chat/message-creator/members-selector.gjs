import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { i18n } from "discourse-i18n";
import ChatablesLoader from "./lib/chatables-loader";
import List from "./list";
import ListHandler from "./list-handler";
import Members from "./members";

export default class MembersSelector extends Component {
  @service siteSettings;

  @tracked chatables = [];
  @tracked filter = "";
  @tracked highlightedMember;
  @tracked highlightedChatable;

  placeholder = i18n("chat.direct_message_creator.group_name");

  get items() {
    return this.chatables.filter(
      (c) => !this.highlightedMemberIds.includes(c.model.id)
    );
  }

  get highlightedMemberIds() {
    return this.args.members.map((u) => u.model.id);
  }

  @action
  highlightMember(member) {
    this.highlightedMember = member;
  }

  @action
  highlightChatable(chatable) {
    this.highlightedChatable = chatable;
  }

  @action
  selectChatable(chatable) {
    if (!chatable.enabled) {
      return;
    }

    const chatableMembers =
      chatable.type === "group" ? chatable.model.chat_enabled_user_count : 1;

    if (
      this.args.membersCount + chatableMembers >
      this.siteSettings.chat_max_direct_message_users
    ) {
      return;
    }

    if (this.highlightedMemberIds.includes(chatable.model.id)) {
      this.unselectMember(chatable);
    } else {
      this.args.onChange?.([...this.args.members, chatable]);
      this.highlightedChatable = this.items[0];
    }

    this.filter = "";
    this.focusFilterAction?.();
    this.highlightedMember = null;
  }

  @action
  registerFocusFilterAction(actionFn) {
    this.focusFilterAction = actionFn;
  }

  @action
  onFilter(event) {
    this.searchHandler = discourseDebounce(
      this,
      this.fetch,
      event.target.value,
      INPUT_DELAY
    );
  }

  @action
  async fetch(term) {
    this.highlightedMember = null;

    const loader = new ChatablesLoader(this);
    this.chatables = await loader.search(term, {
      includeCategoryChannels: false,
      includeDirectMessageChannels: false,
      excludedMembershipsChannelId: this.args.channel?.id,
    });

    this.highlightedChatable = this.items[0];
  }

  @action
  unselectMember(removedMember) {
    this.args.onChange?.(
      this.args.members.filter((member) => member !== removedMember)
    );
    this.highlightedMember = null;
    this.highlightedChatable = this.items[0];
    this.focusFilterAction?.();
  }

  <template>
    <ListHandler
      @items={{this.items}}
      @highlightedItem={{this.highlightedChatable}}
      @onHighlight={{this.highlightChatable}}
      @onSelect={{this.selectChatable}}
    >
      <div class="chat-message-creator__add-members-header-container">
        <div class="chat-message-creator__add-members-header">
          <Members
            @filter={{this.filter}}
            @members={{@members}}
            @highlightedMember={{this.highlightedMember}}
            @onFilter={{this.onFilter}}
            @registerFocusFilterAction={{this.registerFocusFilterAction}}
            @onHighlightMember={{this.highlightMember}}
            @onSelectMember={{this.unselectMember}}
          />

          <DButton
            class="btn-flat chat-message-creator__add-members__close-btn"
            @action={{@cancel}}
            @icon="xmark"
          />
        </div>
      </div>

      <List
        @items={{this.items}}
        @highlightedItem={{this.highlightedChatable}}
        @onSelect={{this.selectChatable}}
        @onHighlight={{this.highlightChatable}}
        @maxReached={{@maxReached}}
        @membersCount={{@membersCount}}
      />

    </ListHandler>
  </template>
}
