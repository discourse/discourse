import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import Logo from "discourse/components/header/logo";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { AI_PANEL, CHANNELS_PANEL, DMS_PANEL } from "../lib/constants.js";
import { serverMenuItems } from "../lib/server-menu.js";
import ActionMenu from "./action-menu.gjs";

// The bar above the channel list: the server's name (or logo), opening the
// site-wide pages core's header used to link to, the switch to the user's DMs
// (the Home view), and where you make channels that don't belong to a
// section.
export default class ServerHeader extends Component {
  @service currentUser;
  @service menu;
  @service session;
  @service siteSettings;
  @service sidebarState;

  // Picked the way core's home logo picks it: the dark logo leads when the
  // default color scheme is dark, and is swapped in by the browser otherwise.
  get logo() {
    if (!settings.show_logo) {
      return null;
    }

    const light = this.siteSettings.site_logo_url;
    const dark = this.siteSettings.site_logo_dark_url;
    const url = this.session.defaultColorSchemeIsDark ? dark || light : light;

    if (!url) {
      return null;
    }

    return {
      url,
      darkUrl: this.session.darkModeAvailable ? dark : null,
    };
  }

  get reviewCount() {
    return this.currentUser?.can_review ? this.currentUser.reviewable_count : 0;
  }

  // Discourse AI's own header button is out of sight in this layout, so this
  // stands in for it, under the same conditions.
  get showAiConversations() {
    const models = this.currentUser?.ai_available_llm_models;
    if (
      this.args.inAdmin ||
      !this.args.aiConversations?.manager ||
      !settings.ai_conversations_link ||
      !this.siteSettings.ai_bot_enabled ||
      !models
    ) {
      return false;
    }

    return (this.currentUser.ai_enabled_agents || []).some(
      (agent) =>
        agent.allow_personal_messages &&
        (agent.has_default_llm || models.length)
    );
  }

  // Admin has no use for channels, so their buttons make way there.
  get showDirectMessages() {
    return this.args.directMessages?.available && !this.args.inAdmin;
  }

  get showCreate() {
    return this.args.canCreate && !this.args.inAdmin;
  }

  get show() {
    return (
      this.args.always ||
      [CHANNELS_PANEL, DMS_PANEL, AI_PANEL].includes(
        this.sidebarState.currentPanelKey
      )
    );
  }

  @action
  toggleAiConversations() {
    this.args.aiConversations.toggle();
  }

  @action
  toggleDirectMessages() {
    // Letting go of the AI list can bring the DMs back on its own, so whether
    // to show them is decided first.
    const show = !this.args.directMessages.active;
    this.args.aiConversations?.release();
    this.args.directMessages.show(show);
  }

  @action
  openMenu(event) {
    this.menu.show(event.currentTarget, {
      identifier: "concord-server-menu",
      component: ActionMenu,
      data: { items: serverMenuItems(getOwner(this)) },
      placement: "bottom-start",
      modalForMobile: true,
    });
  }

  <template>
    {{#if this.show}}
      <div class="concord-server-header">
        <button
          class="concord-server-header__name btn-transparent"
          type="button"
          {{on "click" this.openMenu}}
        >
          {{#if this.logo}}
            <span class="concord-server-header__logo">
              <Logo
                @darkUrl={{this.logo.darkUrl}}
                @key="logo-big"
                @title={{this.siteSettings.title}}
                @url={{this.logo.url}}
              />
            </span>
          {{else}}
            <span class="concord-server-header__title">
              {{this.siteSettings.title}}
            </span>
          {{/if}}
          {{#if this.reviewCount}}
            <span
              class="concord-server-header__review-badge"
              title={{i18n "review.title"}}
            >{{this.reviewCount}}</span>
          {{/if}}
          {{dIcon "angle-down"}}
        </button>

        {{#if this.showAiConversations}}
          <DButton
            aria-pressed={{if @aiConversations.active "true" "false"}}
            class={{dConcatClass
              "btn-flat concord-server-header__ai"
              (if @aiConversations.active "--active")
            }}
            @action={{this.toggleAiConversations}}
            @icon="far-discobot"
            @translatedTitle={{i18n (themePrefix "ai_conversations")}}
          />
        {{/if}}

        {{#if this.showDirectMessages}}
          <DButton
            aria-pressed={{if @directMessages.active "true" "false"}}
            class={{dConcatClass
              "btn-flat concord-server-header__dms"
              (if @directMessages.active "--active")
            }}
            @action={{this.toggleDirectMessages}}
            @icon="far-comments"
            @translatedTitle={{i18n (themePrefix "direct_messages.title")}}
          >
            {{#if @directMessages.unreadCount}}
              <span
                class="concord-server-header__dms-badge"
              >{{@directMessages.unreadCount}}</span>
            {{/if}}
          </DButton>
        {{/if}}

        {{#if this.showCreate}}
          <DButton
            class="btn-flat concord-server-header__create"
            @action={{fn @onCreate null}}
            @icon="plus"
            @title={{themePrefix "create_channel.action"}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
