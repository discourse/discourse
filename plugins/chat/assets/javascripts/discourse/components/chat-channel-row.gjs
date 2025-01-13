import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import { and, eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";
import ChannelName from "discourse/plugins/chat/discourse/components/channel-name";
import ChatChannelMetadata from "discourse/plugins/chat/discourse/components/chat-channel-metadata";
import ToggleChannelMembershipButton from "discourse/plugins/chat/discourse/components/toggle-channel-membership-button";

const FADEOUT_CLASS = "-fade-out";

export default class ChatChannelRow extends Component {
  @service api;
  @service capabilities;
  @service chat;
  @service currentUser;
  @service router;
  @service site;

  @tracked isAtThreshold = false;
  @tracked shouldRemoveChannel = false;
  @tracked showRemoveButton = false;
  @tracked swipableRow = null;
  @tracked shouldReset = false;
  @tracked diff = 0;
  @tracked rowStyle = null;
  @tracked canSwipe = true;

  registerSwipableRow = modifierFn((element) => {
    this.swipableRow = element;
  });

  onReset = modifierFn((element) => {
    const handler = () => {
      this.rowStyle = htmlSafe("margin-right: 0px;");
      this.showRemoveButton = false;
      this.shouldReset = false;
    };

    element.addEventListener("transitionend", handler, { once: true });

    return () => {
      element.removeEventListener("transitionend", handler);
      this.rowStyle = htmlSafe("margin-right: 0px;");
      this.showRemoveButton = false;
      this.shouldReset = false;
    };
  });

  onRemoveChannel = modifierFn((element) => {
    element.addEventListener(
      "transitionend",
      () => {
        this.chat.unfollowChannel(this.args.channel).catch(popupAjaxError);
      },
      { once: true }
    );

    element.classList.add(FADEOUT_CLASS);
  });

  handleSwipe = modifierFn((element) => {
    element.addEventListener("touchstart", this.onSwipeStart, {
      passive: true,
    });
    element.addEventListener("touchmove", this.onSwipe, {
      passive: true,
    });
    element.addEventListener("touchend", this.onSwipeEnd);

    return () => {
      element.removeEventListener("touchstart", this.onSwipeStart);
      element.removeEventListener("touchmove", this.onSwipe);
      element.removeEventListener("touchend", this.onSwipeEnd);
    };
  });

  @bind
  onSwipeStart(event) {
    this._initialX = event.changedTouches[0].screenX;
  }

  @bind
  onSwipe(event) {
    this.showRemoveButton = true;
    this.shouldReset = false;
    this.isAtThreshold = false;

    const threshold = window.innerWidth / 3;
    const touchX = event.changedTouches[0].screenX;

    this.diff = this._initialX - touchX;
    this.isAtThreshold = this.diff >= threshold;

    // ensures we will go back to the initial position when swiping very fast
    if (this.diff > 25) {
      if (this.isAtThreshold) {
        this.diff = threshold + (this.diff - threshold) * 0.1;
      }

      this.rowStyle = htmlSafe(`margin-right: ${this.diff}px;`);
    } else {
      this.rowStyle = htmlSafe("margin-right: 0px;");
    }
  }

  @bind
  onSwipeEnd() {
    if (this.isAtThreshold) {
      this.rowStyle = htmlSafe("margin-right: 0px;");
      this.shouldRemoveChannel = true;
    } else {
      this.shouldReset = true;
    }
  }

  get shouldHandleSwipe() {
    return this.capabilities.touch && this.args.channel.isDirectMessageChannel;
  }

  get leaveDirectMessageLabel() {
    return i18n("chat.direct_messages.close");
  }

  get leaveChannelLabel() {
    return i18n("chat.channel_settings.leave_channel");
  }

  get channelHasUnread() {
    return (
      this.args.channel.tracking.unreadCount > 0 ||
      this.args.channel.unreadThreadsCountSinceLastViewed > 0
    );
  }

  get shouldRenderLastMessage() {
    return (
      this.site.mobileView &&
      this.args.channel.isDirectMessageChannel &&
      this.args.channel.lastMessage
    );
  }

  get #firstDirectMessageUser() {
    return this.args.channel?.chatable?.users?.firstObject;
  }

  @action
  startTrackingStatus() {
    this.#firstDirectMessageUser?.statusManager.trackStatus();
  }

  @action
  stopTrackingStatus() {
    this.#firstDirectMessageUser?.statusManager.stopTrackingStatus();
  }

  <template>
    <LinkTo
      @route="chat.channel"
      @models={{@channel.routeModels}}
      class={{concatClass
        "chat-channel-row"
        (if @channel.focused "focused")
        (if @channel.currentUserMembership.muted "muted")
        (if @options.leaveButton "can-leave")
        (if (eq this.chat.activeChannel.id @channel.id) "active")
        (if this.channelHasUnread "has-unread")
      }}
      tabindex="0"
      data-chat-channel-id={{@channel.id}}
      {{didInsert this.startTrackingStatus}}
      {{willDestroy this.stopTrackingStatus}}
      {{(if this.shouldRemoveChannel (modifier this.onRemoveChannel))}}
    >
      <div
        class={{concatClass
          "chat-channel-row__content"
          (if @channel.isCategoryChannel "is-category" "is-dm")
          (if this.shouldReset "-animate-reset")
        }}
        {{(if this.shouldHandleSwipe (modifier this.registerSwipableRow))}}
        {{(if this.shouldHandleSwipe (modifier this.handleSwipe))}}
        {{(if this.shouldReset (modifier this.onReset))}}
        style={{this.rowStyle}}
      >
        <ChannelIcon @channel={{@channel}} />
        <div class="chat-channel-row__info">
          <ChannelName @channel={{@channel}} @unreadIndicator={{true}} />
          <ChatChannelMetadata @channel={{@channel}} />
          {{#if this.shouldRenderLastMessage}}
            <div class="chat-channel__last-message">
              {{replaceEmoji (htmlSafe @channel.lastMessage.excerpt)}}
            </div>
          {{/if}}
        </div>

        {{#if
          (and @options.leaveButton @channel.isFollowing this.site.desktopView)
        }}
          <ToggleChannelMembershipButton
            @channel={{@channel}}
            @options={{hash
              leaveClass="btn-flat chat-channel-leave-btn"
              labelType="none"
              leaveIcon="xmark"
              leaveTitle=(if
                @channel.isDirectMessageChannel
                this.leaveDirectMessageLabel
                this.leaveChannelLabel
              )
            }}
          />
        {{/if}}
      </div>

      {{#if this.showRemoveButton}}
        <div
          class={{concatClass
            "chat-channel-row__action-btn"
            (if this.isAtThreshold "-at-threshold" "-not-at-threshold")
          }}
        >
          {{icon "circle-xmark"}}
        </div>
      {{/if}}
    </LinkTo>
  </template>
}
