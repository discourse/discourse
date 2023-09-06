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

export default class ChatChannelRow extends Component {
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
      {{this.handleSwipe}}
      {{(if this.scheduleRowRemoval (modifier this.rowRemoval))}}
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
              this.leaveChanelLabel
            )
          }}
        />
      {{/if}}

      <div
        class={{concatClass
          "chat-channel-row__action-btn"
          (if this.canCancelAction "-cancel" "-remove")
        }}
        {{this.removeButton}}
      >
        {{#if this.canCancelAction}}
          {{this.cancelActionLabel}}
        {{else}}
          {{this.removeActionLabel}}
        {{/if}}
      </div>
    </LinkTo>
  </template>

  @service router;
  @service chat;
  @service currentUser;
  @service site;
  @service api;

  @tracked scheduleRowRemoval = false;
  @tracked reachedThreshold = false;
  @tracked canCancelAction = false;

  removeButton = modifier((element) => {
    this.removeButton = element;
    this.removeButton.style.left = window.innerWidth + "px";
  });

  rowRemoval = modifier((element) => {
    element.classList.add("-fade-out");

    const handler = discourseLater(
      () => this.chat.unfollowChannel(this.args.channel).catch(popupAjaxError),
      250
    );

    return () => {
      cancel(handler);
    };
  });

  handleSwipe = modifier((element) => {
    this.element = element;

    element.addEventListener("touchstart", this.onSwipeStart);
    element.addEventListener("touchmove", this.onSwipeMove);
    element.addEventListener("touchend", this.onSwipeEnd);

    return () => {
      element.removeEventListener("touchstart", this.onSwipeStart);
      element.removeEventListener("touchmove", this.onSwipeMove);
      element.removeEventListener("touchend", this.onSwipeEnd);
    };
  });

  @bind
  onSwipeStart(event) {
    if (!this.removeButton) {
      return;
    }

    this.reachedThreshold = false;
    this.canCancelAction = false;
    this.initialX = event.changedTouches[0].screenX;
  }

  @bind
  onSwipeMove(event) {
    event.preventDefault();

    const diff = this.initialX - event.changedTouches[0].screenX;

    if (diff < 10) {
      this.canCancelAction = false;
      this.reachedThreshold = false;
      this.element.style.left = "0px";
      return;
    }

    if (diff >= window.innerWidth / 3) {
      this.canCancelAction = false;
      this.reachedThreshold = true;
      return;
    } else {
      if (this.reachedThreshold) {
        this.canCancelAction = true;
      }
    }

    this.removeButton.style.width = diff + "px";
    this.element.style.left =
      -(this.initialX - event.changedTouches[0].screenX) + "px";
  }

  @bind
  onSwipeEnd() {
    const diff = this.initialX - event.changedTouches[0].screenX;

    if (diff >= window.innerWidth / 3) {
      this.scheduleRowRemoval = true;
    }

    this.element.style.left = "0px";
  }

  get cancelActionLabel() {
    return "Cancel";
  }

  get removeActionLabel() {
    return "Remove";
  }

  get leaveDirectMessageLabel() {
    return I18n.t("chat.direct_messages.leave");
  }

  get leaveChanelLabel() {
    return I18n.t("chat.channel_settings.leave_channel");
  }

  @action
  startTrackingStatus() {
    this.#firstDirectMessageUser?.trackStatus();
  }

  @action
  stopTrackingStatus() {
    this.#firstDirectMessageUser?.stopTrackingStatus();
  }

  get channelHasUnread() {
    return this.args.channel.tracking.unreadCount > 0;
  }

  get #firstDirectMessageUser() {
    return this.args.channel?.chatable?.users?.firstObject;
  }
}
