import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import concatClass from "discourse/helpers/concat-class";
import eq from "truth-helpers/helpers/eq";
import and from "truth-helpers/helpers/and";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";
import ChatChannelMetadata from "discourse/plugins/chat/discourse/components/chat-channel-metadata";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ToggleChannelMembershipButton from "discourse/plugins/chat/discourse/components/toggle-channel-membership-button";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { hash } from "@ember/helper";
import I18n from "I18n";
import { modifier } from "ember-modifier";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import { htmlSafe } from "@ember/template";

const FADEOUT_CLASS = "-fade-out";

export default class ChatChannelRow extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
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
          (if this.shouldReset "-animate-reset")
        }}
        {{(if this.shouldHandleSwipe (modifier this.registerSwipableRow))}}
        {{(if this.shouldHandleSwipe (modifier this.handleSwipe))}}
        {{(if this.shouldReset (modifier this.onReset))}}
        style={{this.rowStyle}}
      >
        <ChatChannelTitle @channel={{@channel}} />
        <ChatChannelMetadata @channel={{@channel}} @unreadIndicator={{true}} />

        {{#if
          (and @options.leaveButton @channel.isFollowing this.site.desktopView)
        }}
          <ToggleChannelMembershipButton
            @channel={{@channel}}
            @options={{hash
              leaveClass="btn-flat chat-channel-leave-btn"
              labelType="none"
              leaveIcon="times"
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
          {{icon "times-circle"}}
        </div>
      {{/if}}
    </LinkTo>
  </template>

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

  registerSwipableRow = modifier((element) => {
    this.swipableRow = element;
  });

  onReset = modifier((element) => {
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

  onRemoveChannel = modifier((element) => {
    element.addEventListener(
      "transitionend",
      () => {
        this.chat.unfollowChannel(this.args.channel).catch(popupAjaxError);
      },
      { once: true }
    );

    element.classList.add(FADEOUT_CLASS);
  });

  handleSwipe = modifier((element) => {
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
    return I18n.t("chat.direct_messages.leave");
  }

  get leaveChannelLabel() {
    return I18n.t("chat.channel_settings.leave_channel");
  }

  get channelHasUnread() {
    return this.args.channel.tracking.unreadCount > 0;
  }

  get #firstDirectMessageUser() {
    return this.args.channel?.chatable?.users?.firstObject;
  }

  @action
  startTrackingStatus() {
    this.#firstDirectMessageUser?.trackStatus();
  }

  @action
  stopTrackingStatus() {
    this.#firstDirectMessageUser?.stopTrackingStatus();
  }
}
