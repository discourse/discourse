/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat, hash } from "@ember/helper";
import { computed, set } from "@ember/object";
import { getOwner } from "@ember/owner";
import { compare } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import BookmarkMenu from "discourse/components/bookmark-menu";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import PinnedButton from "discourse/components/pinned-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import UserTip from "discourse/components/user-tip";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { getTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import TopicBookmarkManager from "discourse/lib/topic-bookmark-manager";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import { eq, gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function bind(fn, context) {
  return fn.bind(context);
}

@tagName("")
export default class TopicFooterButtons extends Component {
  @computed("currentUser.can_send_private_messages")
  get canSendPms() {
    return this.currentUser?.can_send_private_messages;
  }

  set canSendPms(value) {
    set(this, "currentUser.can_send_private_messages", value);
  }

  @computed("topic.details.can_invite_to")
  get canInviteTo() {
    return this.topic?.details?.can_invite_to;
  }

  set canInviteTo(value) {
    set(this, "topic.details.can_invite_to", value);
  }

  @computed("currentUser.user_option.enable_defer")
  get canDefer() {
    return this.currentUser?.user_option?.enable_defer;
  }

  set canDefer(value) {
    set(this, "currentUser.user_option.enable_defer", value);
  }

  @computed("topic.archived", "topic.closed", "topic.deleted")
  get inviteDisabled() {
    return this.topic?.archived || this.topic?.closed || this.topic?.deleted;
  }

  get inlineButtons() {
    return getTopicFooterButtons(this);
  }

  get inlineDropdowns() {
    return getTopicFooterDropdowns(this);
  }

  @computed("canSendPms", "topic.isPrivateMessage")
  get canArchive() {
    return this.canSendPms && this.topic?.isPrivateMessage;
  }

  get inlineActionables() {
    return (
      this.inlineButtons
        .filter(
          (button) =>
            button.dropdown === false && button.anonymousOnly === false
        )
        .concat(this.inlineDropdowns)
        .sort((a, b) => compare(a?.priority, b?.priority))
        // Reversing the array is necessary because when priorities are not set,
        // we want to show the most recently added item first
        .reverse()
    );
  }

  @computed("topic.bookmarked")
  get topicBookmarkManager() {
    return new TopicBookmarkManager(getOwner(this), this.topic);
  }

  get dropdownButtons() {
    return this.inlineButtons.filter((button) => button.dropdown);
  }

  get loneDropdownButton() {
    return this.dropdownButtons.length === 1 ? this.dropdownButtons[0] : null;
  }

  @computed("topic.isPrivateMessage")
  get showNotificationsButton() {
    return !this.topic?.isPrivateMessage || this.canSendPms;
  }

  @computed("topic.details.notification_level")
  get showNotificationUserTip() {
    return (
      this.topic?.details?.notification_level >= NotificationLevels.TRACKING
    );
  }

  @computed("topic.message_archived")
  get archiveIcon() {
    return this.topic?.message_archived ? "envelope" : "folder";
  }

  @computed("topic.message_archived")
  get archiveTitle() {
    return this.topic?.message_archived
      ? "topic.move_to_inbox.help"
      : "topic.archive_message.help";
  }

  @computed("topic.message_archived")
  get archiveLabel() {
    return this.topic?.message_archived
      ? "topic.move_to_inbox.title"
      : "topic.archive_message.title";
  }

  @computed("topic.isPrivateMessage")
  get showBookmarkLabel() {
    return !this.topic?.isPrivateMessage;
  }

  <template>
    <div
      role="region"
      aria-label={{i18n "topic.footer_buttons.region_label"}}
      id="topic-footer-buttons"
      ...attributes
    >
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

          {{#each this.inlineActionables key="id" as |actionable|}}
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
                    {{#each this.dropdownButtons key="id" as |button|}}
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
            @label="topic.reply.title"
            @title="topic.reply.help"
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
              @triggerSelector=".notifications-button-footer [data-identifier='notifications-tracking']"
              @titleText={{i18n "user_tips.topic_notification_levels.title"}}
              @contentText={{i18n
                "user_tips.topic_notification_levels.content"
              }}
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
    </div>
  </template>
}
