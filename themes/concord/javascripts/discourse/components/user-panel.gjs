import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import Notifications from "discourse/components/header/user-dropdown/notifications";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import ProfileMenuPopover from "./profile-menu-popover.gjs";
import UserMenuPopover from "./user-menu-popover.gjs";

// The panel at the foot of the channel list: who you are, with the
// profile menu behind your name and notifications behind the bell.
export default class UserPanel extends Component {
  @service currentUser;
  @service menu;
  @service siteSettings;

  // Display name over username, as in a chat app, so the username isn't said
  // twice; with no display name, the username stands alone.
  get name() {
    return (
      (this.siteSettings.enable_names && this.currentUser.name?.trim()) ||
      this.currentUser.username
    );
  }

  // The badge core shows on the header avatar, in the same order of priority.
  get notificationCount() {
    return (
      this.currentUser.new_personal_messages_notifications_count ||
      this.currentUser.unseen_reviewable_count ||
      this.currentUser.all_unread_notifications_count
    );
  }

  get subtitle() {
    const { status, username } = this.currentUser;
    if (status?.description) {
      return status.description;
    }
    return this.name.toLowerCase() === username.toLowerCase() ? "" : username;
  }

  @action
  openUserMenu(event) {
    this.menu.show(event.currentTarget, {
      identifier: "concord-user-menu",
      strategy: "fixed",
      component: UserMenuPopover,
      placement: "top-start",
      modalForMobile: true,
    });
  }

  @action
  openProfileMenu(event) {
    this.menu.show(event.currentTarget, {
      identifier: "concord-profile-menu",
      strategy: "fixed",
      component: ProfileMenuPopover,
      placement: "top-end",
      modalForMobile: true,
    });
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  showSignup() {
    getOwner(this).lookup("route:application").send("showCreateAccount");
  }

  <template>
    <div class="concord-user-panel">
      {{#if this.currentUser}}
        <button
          class="concord-user-panel__me btn-transparent"
          title={{i18n "user.avatar.header_title"}}
          type="button"
          {{on "click" this.openProfileMenu}}
        >
          <span class="concord-user-panel__avatar">
            <Notifications />
          </span>
          <span class="concord-user-panel__names">
            <span class="concord-user-panel__name">{{this.name}}</span>
            {{#if this.subtitle}}
              <span
                class="concord-user-panel__subtitle"
              >{{this.subtitle}}</span>
            {{/if}}
          </span>
        </button>
        <DButton
          class="btn-flat concord-user-panel__notifications"
          @icon="bell"
          @title="user.notifications"
          {{on "click" this.openUserMenu}}
        >
          {{#if this.notificationCount}}
            <span class="badge-notification">{{this.notificationCount}}</span>
          {{/if}}
        </DButton>
      {{else}}
        <DButton
          class="btn-primary concord-user-panel__login"
          @action={{this.showLogin}}
          @label="log_in"
        />
        <DButton
          class="btn-default concord-user-panel__signup"
          @action={{this.showSignup}}
          @label="sign_up"
        />
      {{/if}}
    </div>
  </template>
}
