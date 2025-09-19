/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat, hash } from "@ember/helper";
import { computed } from "@ember/object";
import { alias, or } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { attributeBindings } from "@ember-decorators/component";
import { eq, gt } from "truth-helpers";
import BookmarkMenu from "discourse/components/bookmark-menu";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import PinnedButton from "discourse/components/pinned-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import UserTip from "discourse/components/user-tip";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed from "discourse/lib/decorators";
import {
  hasDraft as draftStoreHasDraft,
  invalidateDraftState,
  setDraftFromTopic,
  setDraftSaved,
} from "discourse/lib/draft-state-cache";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { getTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import TopicBookmarkManager from "discourse/lib/topic-bookmark-manager";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import TopicNotificationsButton from "select-kit/components/topic-notifications-button";
import DMenu from "float-kit/components/d-menu";

function bind(fn, context) {
  return fn.bind(context);
}

/**
 * @component TopicFooterButtons
 *
 * @param {Object} topic - The current topic model instance
 * @param {Function} replyToPost - Action to initiate replying in the composer
 */
@attributeBindings("role")
export default class TopicFooterButtons extends Component {
  // Services
  @service appEvents;

  elementId = "topic-footer-buttons";
  role = "region";

  // Tracks if a draft exists for the current topic's draft_key
  hasDraft = false;

  @getTopicFooterButtons() inlineButtons;
  @getTopicFooterDropdowns() inlineDropdowns;

  @alias("currentUser.can_send_private_messages") canSendPms;
  @alias("topic.details.can_invite_to") canInviteTo;
  @alias("currentUser.user_option.enable_defer") canDefer;
  @or("topic.archived", "topic.closed", "topic.deleted") inviteDisabled;

  init() {
    super.init?.(...arguments);

    // Seed from preloaded topic state and compute initial state
    setDraftFromTopic(this.topic);
    this._checkDraft();

    // React to draft lifecycle events to keep the label in sync
    // When the composer is cancelled (saved and closed), or a draft is destroyed,
    // re-check for the current topic's draft.
    this.appEvents?.on("composer:cancelled", this, this._onDraftChanged);
    this.appEvents?.on("draft:destroyed", this, this._onDraftChanged);
    // Also when user drafts change from message bus (store is updated elsewhere)
    this.appEvents?.on("user-drafts:changed", this, this._checkDraft);
    // When a draft is saved client-side, update our local store immediately
    this.appEvents?.on("draft:saved", this, this._onDraftSaved);
  }

  @discourseComputed("canSendPms", "topic.isPrivateMessage")
  canArchive(canSendPms, isPM) {
    return canSendPms && isPM;
  }

  @computed("inlineButtons.[]", "inlineDropdowns.[]")
  get inlineActionables() {
    return this.inlineButtons
      .filterBy("dropdown", false)
      .filterBy("anonymousOnly", false)
      .concat(this.inlineDropdowns)
      .sortBy("priority")
      .reverse();
  }

  @computed("topic")
  get topicBookmarkManager() {
    return new TopicBookmarkManager(getOwner(this), this.topic);
  }

  // topic.assigned_to_user is for backward plugin support
  @discourseComputed("inlineButtons.[]", "topic.assigned_to_user")
  dropdownButtons(inlineButtons) {
    return inlineButtons.filter((button) => button.dropdown);
  }

  @discourseComputed("dropdownButtons.[]")
  loneDropdownButton(dropdownButtons) {
    return dropdownButtons.length === 1 ? dropdownButtons[0] : null;
  }

  @discourseComputed("topic.isPrivateMessage")
  showNotificationsButton(isPM) {
    return !isPM || this.canSendPms;
  }

  @discourseComputed("topic.details.notification_level")
  showNotificationUserTip(notificationLevel) {
    return notificationLevel >= NotificationLevels.TRACKING;
  }

  @discourseComputed("topic.message_archived")
  archiveIcon(archived) {
    return archived ? "envelope" : "folder";
  }

  @discourseComputed("topic.message_archived")
  archiveTitle(archived) {
    return archived ? "topic.move_to_inbox.help" : "topic.archive_message.help";
  }

  @discourseComputed("topic.message_archived")
  archiveLabel(archived) {
    return archived
      ? "topic.move_to_inbox.title"
      : "topic.archive_message.title";
  }

  @discourseComputed("topic.isPrivateMessage")
  showBookmarkLabel(isPM) {
    return !isPM;
  }

  /**
   * Checks if there is a saved draft for the current topic and updates the button label state.
   */
  async _checkDraft() {
    const topic = this.topic;
    if (!topic || !topic.draft_key) {
      this.set?.("hasDraft", false) ?? (this.hasDraft = false);
      return;
    }

    const hasDraft = draftStoreHasDraft(topic.draft_key);
    this.set?.("hasDraft", hasDraft) ?? (this.hasDraft = hasDraft);
  }

  didReceiveAttrs() {
    super.didReceiveAttrs?.(...arguments);
    // Topic changed: refresh from preload and re-check draft state
    setDraftFromTopic(this.topic);
    this._checkDraft();
  }

  willDestroyElement() {
    super.willDestroyElement?.(...arguments);
    this.appEvents?.off("composer:cancelled", this, this._onDraftChanged);
    this.appEvents?.off("draft:destroyed", this, this._onDraftChanged);
    this.appEvents?.off("user-drafts:changed", this, this._checkDraft);
    this.appEvents?.off("draft:saved", this, this._onDraftSaved);
  }

  @discourseComputed("hasDraft")
  replyButtonLabel(hasDraft) {
    return hasDraft ? "topic.open_draft" : "topic.reply.title";
  }

  @discourseComputed("hasDraft")
  replyButtonTitle(hasDraft) {
    return hasDraft ? "topic.open_draft_help" : "topic.reply.help";
  }

  _onDraftChanged() {
    const key = this.topic?.draft_key;
    if (key) {
      invalidateDraftState(key);
    }
    this._checkDraft();
  }

  _onDraftSaved(payload) {
    const key = this.topic?.draft_key;
    if (key && payload?.draftKey === key) {
      setDraftSaved(key, { postId: payload.postId, action: payload.action });
      this._checkDraft();
    }
  }

  <template>
    <div class="topic-footer-main-buttons">
      <div class="topic-footer-main-buttons__actions">
        <TopicAdminMenu
          @topic={{this.topic}}
          @toggleMultiSelect={{this.toggleMultiSelect}}
          @showTopicSlowModeUpdate={{this.showTopicSlowModeUpdate}}
          @deleteTopic={{this.deleteTopic}}
          @recoverTopic={{this.recoverTopic}}
          @toggleFeaturedOnProfile={{this.toggleFeaturedOnProfile}}
          @toggleClosed={{this.toggleClosed}}
          @toggleArchived={{this.toggleArchived}}
          @toggleVisibility={{this.toggleVisibility}}
          @showTopicTimerModal={{this.showTopicTimerModal}}
          @showFeatureTopic={{this.showFeatureTopic}}
          @showChangeTimestamp={{this.showChangeTimestamp}}
          @resetBumpDate={{this.resetBumpDate}}
          @convertToPublicTopic={{this.convertToPublicTopic}}
          @convertToPrivateMessage={{this.convertToPrivateMessage}}
          @buttonClasses="topic-footer-button"
        />

        {{#each this.inlineActionables as |actionable|}}
          {{#if (eq actionable.type "inline-button")}}
            {{#if (eq actionable.id "bookmark")}}
              <BookmarkMenu
                @showLabel={{this.showBookmarkLabel}}
                @bookmarkManager={{this.topicBookmarkManager}}
                @buttonClasses="btn-default topic-footer-button"
              />
            {{else}}
              <DButton
                @action={{actionable.action}}
                @icon={{actionable.icon}}
                @translatedLabel={{actionable.label}}
                @translatedTitle={{actionable.title}}
                @translatedAriaLabel={{actionable.ariaLabel}}
                @disabled={{actionable.disabled}}
                id={{concat "topic-footer-button-" actionable.id}}
                class={{concatClass
                  "btn-default"
                  "topic-footer-button"
                  actionable.classNames
                }}
              />
            {{/if}}
          {{else}}
            <DropdownSelectBox
              @id={{concat "topic-footer-dropdown-" actionable.id}}
              @value={{actionable.value}}
              @content={{actionable.content}}
              @onChange={{bind actionable.action this}}
              @options={{hash
                icon=actionable.icon
                none=actionable.noneItem
                disabled=actionable.disabled
              }}
              class={{concatClass
                "topic-footer-dropdown"
                actionable.classNames
              }}
            />
          {{/if}}
        {{/each}}

        {{#if this.site.mobileView}}
          {{#if this.loneDropdownButton}}
            <DButton
              @action={{this.loneDropdownButton.action}}
              @icon={{this.loneDropdownButton.icon}}
              @translatedLabel={{this.loneDropdownButton.label}}
              @translatedTitle={{this.loneDropdownButton.title}}
              @translatedAriaLabel={{this.loneDropdownButton.ariaLabel}}
              @disabled={{this.loneDropdownButton.disabled}}
              id={{concat "topic-footer-button-" this.loneDropdownButton.id}}
              class={{concatClass
                "btn-default"
                "topic-footer-button"
                this.loneDropdownButton.classNames
              }}
            />
          {{else if (gt this.dropdownButtons.length 1)}}
            <DMenu
              @modalForMobile={{true}}
              @identifier="topic-footer-mobile-dropdown"
              class="topic-footer-button btn-default"
            >
              <:trigger>
                {{icon "ellipsis-vertical"}}
              </:trigger>
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#each this.dropdownButtons as |button|}}
                    <dropdown.item>
                      <DButton
                        @action={{button.action}}
                        @icon={{button.icon}}
                        @translatedLabel={{button.label}}
                        @translatedTitle={{button.title}}
                        @translatedAriaLabel={{button.ariaLabel}}
                        @disabled={{button.disabled}}
                        id={{concat "topic-footer-button-" button.id}}
                        class={{concatClass
                          "btn-default"
                          "topic-footer-button"
                          button.classNames
                        }}
                      />
                    </dropdown.item>
                  {{/each}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}

          <PinnedButton
            @pinned={{this.topic.pinned}}
            @topic={{this.topic}}
            @appendReason={{false}}
          />

          {{#if this.showNotificationsButton}}
            <TopicNotificationsButton
              @topic={{this.topic}}
              @appendReason={{false}}
            />
          {{/if}}
        {{/if}}
      </div>

      <PluginOutlet
        @name="topic-footer-main-buttons-before-create"
        @outletArgs={{lazyHash topic=this.topic}}
        @connectorTagName="span"
      />

      {{#if this.topic.details.can_create_post}}
        <DButton
          @icon="reply"
          @action={{this.replyToPost}}
          @label={{this.replyButtonLabel}}
          @title={{this.replyButtonTitle}}
          class="btn-primary create topic-footer-button"
        />
      {{/if}}

      <PluginOutlet
        @name="after-topic-footer-main-buttons"
        @outletArgs={{lazyHash topic=this.topic}}
        @connectorTagName="span"
      />
    </div>

    {{#if this.site.desktopView}}
      <PinnedButton
        @pinned={{this.topic.pinned}}
        @topic={{this.topic}}
        @appendReason={{true}}
      />

      {{#if this.showNotificationsButton}}
        <TopicNotificationsButton
          @topic={{this.topic}}
          @expanded={{true}}
          class="notifications-button-footer"
        />

        {{#if this.showNotificationUserTip}}
          <UserTip
            @id="topic_notification_levels"
            @triggerSelector=".notifications-button-footer details"
            @titleText={{i18n "user_tips.topic_notification_levels.title"}}
            @contentText={{i18n "user_tips.topic_notification_levels.content"}}
            @priority={{800}}
          />
        {{/if}}
      {{/if}}
    {{/if}}

    <PluginOutlet
      @name="after-topic-footer-buttons"
      @outletArgs={{lazyHash topic=this.topic}}
      @connectorTagName="span"
    />
  </template>
}
