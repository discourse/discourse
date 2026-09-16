/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat, hash } from "@ember/helper";
import { computed, set } from "@ember/object";
import { compare } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import PinnedButton from "discourse/components/pinned-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import TopicBookmarksMenu from "discourse/components/topic-bookmarks-menu";
import UserTip from "discourse/components/user-tip";
import DMenu from "discourse/float-kit/components/d-menu";
import lazyHash from "discourse/helpers/lazy-hash";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { getTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import { eq, gt } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

  @computed("showCreate", "topic.details.can_create_post")
  get showCreateButton() {
    return this.showCreate !== false && this.topic?.details?.can_create_post;
  }

  <template>
    <div
      aria-label={{i18n "topic.footer_buttons.region_label"}}
      id="topic-footer-buttons"
      role="region"
      ...attributes
    >
      <div class="topic-footer-main-buttons">
        <div class="topic-footer-main-buttons__actions">
          <TopicAdminMenu
            @buttonClasses="topic-footer-button"
            @convertToPrivateMessage={{this.convertToPrivateMessage}}
            @convertToPublicTopic={{this.convertToPublicTopic}}
            @deleteTopic={{this.deleteTopic}}
            @recoverTopic={{this.recoverTopic}}
            @resetBumpDate={{this.resetBumpDate}}
            @showChangeTimestamp={{this.showChangeTimestamp}}
            @showFeatureTopic={{this.showFeatureTopic}}
            @showTopicSlowModeUpdate={{this.showTopicSlowModeUpdate}}
            @showTopicTimerModal={{this.showTopicTimerModal}}
            @toggleArchived={{this.toggleArchived}}
            @toggleClosed={{this.toggleClosed}}
            @toggleFeaturedOnProfile={{this.toggleFeaturedOnProfile}}
            @toggleMultiSelect={{this.toggleMultiSelect}}
            @toggleVisibility={{this.toggleVisibility}}
            @topic={{this.topic}}
          />

          {{#each this.inlineActionables key="id" as |actionable|}}
            {{#if (eq actionable.type "inline-button")}}
              {{#if (eq actionable.id "bookmark")}}
                <TopicBookmarksMenu
                  @buttonClasses="btn-default topic-footer-button"
                  @showLabel={{this.showBookmarkLabel}}
                  @topic={{this.topic}}
                />
              {{else}}
                <DButton
                  class={{dConcatClass
                    "btn-default"
                    "topic-footer-button"
                    actionable.classNames
                  }}
                  id={{concat "topic-footer-button-" actionable.id}}
                  @action={{actionable.action}}
                  @disabled={{actionable.disabled}}
                  @icon={{actionable.icon}}
                  @translatedAriaLabel={{actionable.ariaLabel}}
                  @translatedLabel={{actionable.label}}
                  @translatedTitle={{actionable.title}}
                />
              {{/if}}
            {{else}}
              <DropdownSelectBox
                class={{dConcatClass
                  "topic-footer-dropdown"
                  actionable.classNames
                }}
                @content={{actionable.content}}
                @id={{concat "topic-footer-dropdown-" actionable.id}}
                @onChange={{bind actionable.action this}}
                @options={{hash
                  icon=actionable.icon
                  none=actionable.noneItem
                  disabled=actionable.disabled
                }}
                @value={{actionable.value}}
              />
            {{/if}}
          {{/each}}

          {{#if this.site.mobileView}}
            {{#if this.loneDropdownButton}}
              <DButton
                class={{dConcatClass
                  "btn-default"
                  "topic-footer-button"
                  this.loneDropdownButton.classNames
                }}
                id={{concat "topic-footer-button-" this.loneDropdownButton.id}}
                @action={{this.loneDropdownButton.action}}
                @disabled={{this.loneDropdownButton.disabled}}
                @icon={{this.loneDropdownButton.icon}}
                @translatedAriaLabel={{this.loneDropdownButton.ariaLabel}}
                @translatedLabel={{this.loneDropdownButton.label}}
                @translatedTitle={{this.loneDropdownButton.title}}
              />
            {{else if (gt this.dropdownButtons.length 1)}}
              <DMenu
                class="topic-footer-button btn-default"
                @identifier="topic-footer-mobile-dropdown"
                @modalForMobile={{true}}
              >
                <:trigger>
                  {{dIcon "ellipsis-vertical"}}
                </:trigger>
                <:content>
                  <DDropdownMenu as |dropdown|>
                    {{#each this.dropdownButtons key="id" as |button|}}
                      <dropdown.item>
                        <DButton
                          class={{dConcatClass
                            "topic-footer-button"
                            button.classNames
                          }}
                          id={{concat "topic-footer-button-" button.id}}
                          @action={{button.action}}
                          @disabled={{button.disabled}}
                          @icon={{button.icon}}
                          @translatedAriaLabel={{button.ariaLabel}}
                          @translatedLabel={{button.label}}
                          @translatedTitle={{button.title}}
                        />
                      </dropdown.item>
                    {{/each}}
                  </DDropdownMenu>
                </:content>
              </DMenu>
            {{/if}}

            <PinnedButton
              @appendReason={{false}}
              @pinned={{this.topic.pinned}}
              @topic={{this.topic}}
            />

            {{#if this.showNotificationsButton}}
              <TopicNotificationsButton
                @appendReason={{false}}
                @topic={{this.topic}}
              />
            {{/if}}
          {{/if}}
        </div>

        <PluginOutlet
          @connectorTagName="span"
          @name="topic-footer-main-buttons-before-create"
          @outletArgs={{lazyHash topic=this.topic}}
        />

        {{#if this.showCreateButton}}
          <DButton
            class="btn-primary create topic-footer-button"
            @action={{this.replyToPost}}
            @icon="reply"
            @label="topic.reply.title"
            @title="topic.reply.help"
          />
        {{/if}}

        <PluginOutlet
          @connectorTagName="span"
          @name="after-topic-footer-main-buttons"
          @outletArgs={{lazyHash topic=this.topic}}
        />
      </div>

      {{#if this.site.desktopView}}
        <PinnedButton
          @appendReason={{true}}
          @pinned={{this.topic.pinned}}
          @topic={{this.topic}}
        />

        {{#if this.showNotificationsButton}}
          <TopicNotificationsButton
            class="notifications-button-footer"
            @expanded={{true}}
            @topic={{this.topic}}
          />

          {{#if this.showNotificationUserTip}}
            <UserTip
              @contentText={{i18n
                "user_tips.topic_notification_levels.content"
              }}
              @id="topic_notification_levels"
              @priority={{800}}
              @titleText={{i18n "user_tips.topic_notification_levels.title"}}
              @triggerSelector=".notifications-button-footer [data-identifier='notifications-tracking']"
            />
          {{/if}}
        {{/if}}
      {{/if}}

      <PluginOutlet
        @connectorTagName="span"
        @name="after-topic-footer-buttons"
        @outletArgs={{lazyHash topic=this.topic}}
      />
    </div>
  </template>
}
