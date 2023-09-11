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
import discourseLater from "discourse-common/lib/later";
import { cancel } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";

const RESET_CLASS = "-reset";
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
      {{(if this.shouldHandleSwipe (modifier this.registerSwipableRow))}}
      {{(if this.shouldHandleSwipe (modifier this.handleSwipe))}}
      {{(if this.shouldRemoveChannel (modifier this.onRemoveChannel))}}
      {{(if this.shouldResetRow (modifier this.onResetRow))}}
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

      {{#if this.shouldHandleSwipe}}
        <div
          class={{concatClass
            "chat-channel-row__action-btn"
            (if this.isCancelling "-cancel" "-leave")
          }}
          {{this.registerActionButton}}
          {{this.positionActionButton}}
        >
          {{#if this.isCancelling}}
            {{this.cancelActionLabel}}
          {{else}}
            {{this.removeActionLabel}}
          {{/if}}
        </div>
      {{/if}}
    </LinkTo>
  </template>

  @service router;
  @service chat;
  @service capabilities;
  @service currentUser;
  @service site;
  @service api;

  @tracked shouldRemoveChannel = false;
  @tracked hasReachedThreshold = false;
  @tracked isCancelling = false;
  @tracked shouldResetRow = false;
  @tracked actionButton;
  @tracked swipableRow;

  positionActionButton = modifier((element) => {
    element.style.left = "100%";
  });

  registerActionButton = modifier((element) => {
    this.actionButton = element;
  });

  registerSwipableRow = modifier((element) => {
    this.swipableRow = element;
  });

  onRemoveChannel = modifier(() => {
    this.swipableRow.classList.add(FADEOUT_CLASS);

    const handler = discourseLater(() => {
      this.chat.unfollowChannel(this.args.channel).catch(popupAjaxError);
    }, 250);

    return () => {
      cancel(handler);
    };
  });

  handleSwipe = modifier((element) => {
    element.addEventListener("touchstart", this.onSwipeStart, {
      passive: true,
    });
    element.addEventListener("touchmove", this.onSwipe);
    element.addEventListener("touchend", this.onSwipeEnd);

    return () => {
      element.removeEventListener("touchstart", this.onSwipeStart);
      element.removeEventListener("touchmove", this.onSwipe);
      element.removeEventListener("touchend", this.onSwipeEnd);
    };
  });

  onResetRow = modifier(() => {
    this.swipableRow.classList.add(RESET_CLASS);
    this.swipableRow.style.left = "0px";

    const handler = discourseLater(() => {
      this.isCancelling = false;
      this.hasReachedThreshold = false;
      this.shouldResetRow = false;
      this.swipableRow.classList.remove(RESET_CLASS);
    }, 250);

    return () => {
      cancel(handler);
      this.swipableRow.classList.remove(RESET_CLASS);
    };
  });

  _lastX = null;
  _towardsThreshold = false;

  @bind
  onSwipeStart(event) {
    this.hasReachedThreshold = false;
    this.isCancelling = false;
    this._lastX = this.initialX = event.changedTouches[0].screenX;
  }

  @bind
  onSwipe(event) {
    event.preventDefault();

    const touchX = event.changedTouches[0].screenX;
    const diff = this.initialX - touchX;

    // we don't state to be too sensitive to the touch
    if (Math.abs(this._lastX - touchX) > 5) {
      this._towardsThreshold = this._lastX >= touchX;
      this._lastX = touchX;
    }

    // ensures we will go back to the initial position when swiping very fast
    if (diff < 10) {
      this.isCancelling = false;
      this.hasReachedThreshold = false;
      this.swipableRow.style.left = "0px";
      return;
    }

    if (diff >= window.innerWidth / 3) {
      this.isCancelling = false;
      this.hasReachedThreshold = true;
      return;
    } else {
      this.isCancelling = !this._towardsThreshold;
    }

    this.actionButton.style.width = diff + "px";
    this.swipableRow.style.left = -(this.initialX - touchX) + "px";
  }

  @bind
  onSwipeEnd(event) {
    this._lastX = null;
    const diff = this.initialX - event.changedTouches[0].screenX;

    if (diff >= window.innerWidth / 3) {
      this.swipableRow.style.left = "0px";
      this.shouldRemoveChannel = true;
      return;
    }

    this.isCancelling = true;
    this.shouldResetRow = true;
  }

  get shouldHandleSwipe() {
    return this.capabilities.touch && this.args.channel.isDirectMessageChannel;
  }

  get cancelActionLabel() {
    return I18n.t("cancel_value");
  }

  get removeActionLabel() {
    return I18n.t("chat.remove");
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
