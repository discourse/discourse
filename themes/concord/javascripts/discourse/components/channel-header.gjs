import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Notifications from "discourse/components/header/user-dropdown/notifications";
import LanguageSwitcher from "discourse/components/language-switcher";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import { languageSwitcherEnabled } from "discourse/lib/content-localization";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ActionMenu from "./action-menu.gjs";
import SearchPopover from "./search-popover.gjs";
import ServerHeader from "./server-header.gjs";

const t = (key) => i18n(themePrefix(`channel_header.${key}`));

// Folded into the "…" menu on small screens, where the row has no room.
const COLLAPSIBLE = ["threads", "pins", "settings"];

const isCollapsible = (headerAction) => COLLAPSIBLE.includes(headerAction.id);

/**
 * The top row: the server's name over the channel list, then the
 * current channel's name, description and actions. Rendered inside core's
 * header so everything that sizes itself to the header keeps working.
 */
export default class ChannelHeader extends Component {
  @service appEvents;
  @service currentUser;
  @service header;
  @service menu;
  @service routeHistory;
  @service router;
  @service search;
  @service site;
  @service siteSettings;

  isFolded = (headerAction) =>
    this.moreItems.length > 0 && isCollapsible(headerAction);

  constructor() {
    super(...arguments);
    this.appEvents.on("header:keyboard-trigger", this.onKeyboardTrigger);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("header:keyboard-trigger", this.onKeyboardTrigger);
  }

  get channel() {
    const current = this.args.currentChannel.value;
    let channel;

    switch (current?.type) {
      case "text":
        channel = this.#textChannel(current.channel);
        break;
      case "topic":
        channel = this.#topic(current.topic);
        break;
      case "voice":
        channel = this.#voiceRoom(current.room);
        break;
      case "forum":
        channel = this.#forum(current.category);
        break;
      case "tag":
        channel = { icon: "tag", name: current.tag.name };
        break;
      case "page":
        channel = current;
        break;
    }

    return { actions: [], ...channel };
  }

  // A menu of one would only hide a button behind another, so a lone action
  // stays in the row.
  get moreItems() {
    const items = this.channel.actions.filter(isCollapsible);
    return items.length > 1 ? items : [];
  }

  get moreMenuItems() {
    return this.moreItems.map((headerAction) => ({
      id: headerAction.id,
      label: headerAction.title,
      icon: headerAction.icon,
      action: headerAction.action,
    }));
  }

  // Core's language switcher is one of its header icons, which are hidden
  // here, so it's shown in this row instead, under the same conditions.
  get showLanguageSwitcher() {
    if (!languageSwitcherEnabled(this.siteSettings)) {
      return false;
    }

    switch (this.siteSettings.content_localization_language_switcher) {
      case "anonymous":
        return !this.currentUser;
      case "all":
        return true;
      default:
        return false;
    }
  }

  // Back to the last page outside admin, as core's "Back to Forum" link does.
  get exitAdminHref() {
    const lastUrl = this.routeHistory.history.find(
      (url) => !url.startsWith("/admin")
    );
    return getURL(lastUrl || "/");
  }

  get memberListAction() {
    return {
      id: "member-list",
      icon: "users",
      title: t("member_list"),
      active: this.args.memberList.active,
      action: () => this.args.memberList.toggle(),
    };
  }

  // A channel made from the create modal has a category of its own under the
  // chat container, which only the channel's own menu deletes along with it.
  get hasBackingCategory() {
    const { type, channel } = this.args.currentChannel.value || {};
    if (type !== "text") {
      return false;
    }

    const category = Category.findById(channel.chatableId);
    return category?.parentCategory?.slug === settings.chat_container_category;
  }

  // Core's search (/) and user menu (p) shortcuts open menus in core's header,
  // which is hidden where this row stands in for it. Core has already
  // handled the event by now, so its menu is closed again and ours opened.
  @bind
  onKeyboardTrigger({ type }) {
    // Like core, it leaves / to the welcome banner's search when that's on
    // screen.
    if (
      type === "search" &&
      !this.site.mobileView &&
      !this.search.welcomeBannerSearchInViewport
    ) {
      this.search.visible = false;
      this.#toggleSearch(
        document.querySelector(".concord-channel-header__search")
      );
    } else if (
      type === "user" &&
      !this.site.mobileView &&
      !this.site.narrowDesktopView
    ) {
      this.header.userVisible = false;
      document.querySelector(".concord-user-panel__notifications")?.click();
    }
  }

  // Core's header owns the slide-in channel list and everything around it
  // (animation, scroll lock, closing on a tap outside), so ask it to toggle.
  @action
  toggleChannelList() {
    this.appEvents.trigger("header:keyboard-trigger", { type: "hamburger" });
  }

  // On small screens, core's user menu slides in from the right, as it does
  // from core's own header.
  @action
  toggleUserMenu() {
    this.appEvents.trigger("header:keyboard-trigger", { type: "user" });
  }

  // In a text channel this is chat's message search, which chat keeps behind
  // its own (hidden) bar's button; that button is missing when chat search is
  // off, and then it's site search like anywhere else.
  @action
  openSearch(event) {
    this.#toggleSearch(event.currentTarget);
  }

  @action
  openMore(event) {
    this.menu.show(event.currentTarget, {
      identifier: "concord-channel-header-more",
      component: ActionMenu,
      data: { items: this.moreMenuItems },
      placement: "bottom-end",
      modalForMobile: true,
    });
  }

  #toggleSearch(anchor) {
    const chatFilter = document.querySelector(
      ".c-routes.--channel .c-navbar__filter"
    );
    if (this.args.currentChannel.value?.type === "text" && chatFilter) {
      chatFilter.click();
      return;
    }

    if (this.site.mobileView) {
      if (this.router.currentRouteName === "full-page-search") {
        document.querySelector(".full-page-search")?.focus();
        return;
      }

      const context = this.search.searchContext;
      DiscourseURL.routeTo(
        context
          ? `/search?context=${context.type}&context_id=${context.id}&skip_context=true`
          : "/search"
      );
      return;
    }

    if (this.menu.getByIdentifier("concord-search")) {
      this.menu.close("concord-search");
      return;
    }

    this.menu.show(anchor, {
      identifier: "concord-search",
      component: SearchPopover,
      placement: "bottom-end",
      // The panel's own width rules; the menu's default cap is narrower.
      maxWidth: "none",
      modalForMobile: true,
    });
  }

  #textChannel(channel) {
    if (!channel) {
      return;
    }

    const models = channel.routeModels;
    const go = (route) => () => this.router.transitionTo(route, ...models);

    return {
      icon: channel.isDirectMessageChannel ? "at" : "hashtag",
      name: channel.title,
      description: channel.description,
      actions: [
        channel.threadingEnabled && {
          id: "threads",
          icon: "discourse-threads",
          title: t("threads"),
          action: go("chat.channel.threads"),
        },
        {
          id: "pins",
          icon: "thumbtack",
          title: t("pins"),
          action: go("chat.channel.pins"),
        },
        {
          id: "settings",
          icon: "gear",
          title: t("settings"),
          action: go("chat.channel.info.settings"),
        },
      ].filter(Boolean),
    };
  }

  // The topic list's own controls already offer a new topic. Settings sit
  // here like a text channel's, rather than in the list's controls.
  #forum(category) {
    return {
      icon: "fab-discourse",
      name: category.displayName,
      description: category.description_text,
      actions: [
        category.can_edit && {
          id: "settings",
          icon: "gear",
          title: t("settings"),
          action: () =>
            DiscourseURL.routeTo(`/c/${Category.slugFor(category)}/edit`),
        },
      ].filter(Boolean),
    };
  }

  // A topic is a post in a forum channel: its title leads, back to its top,
  // with the category it's in underneath, and the icon goes back to it.
  #topic(topic) {
    if (!topic) {
      return;
    }

    const category = topic.category;

    return {
      icon: "fab-discourse",
      // Escaped by the server, with its emoji drawn, as core's header shows it.
      name: topic.fancyTitle ? trustHTML(topic.fancyTitle) : topic.title,
      nameHref: topic.firstPostUrl,
      description: category?.displayName,
      descriptionHref: category?.url,
      back: category && {
        href: category.url,
        title: i18n(themePrefix("channel_header.back"), {
          name: category.displayName,
        }),
      },
    };
  }

  #voiceRoom(room) {
    if (!room) {
      return;
    }

    return {
      icon: "volume-high",
      name: room.name,
      description: room.description_excerpt,
    };
  }

  <template>
    {{! Core's header contents make way while this is shown. }}
    {{bodyClass "concord-header"}}
    {{#if this.hasBackingCategory}}
      {{bodyClass "concord-backed-channel"}}
    {{/if}}
    <div class="concord-channel-header">
      <ServerHeader
        @aiConversations={{@aiConversations}}
        @always={{true}}
        @canCreate={{@canCreate}}
        @directMessages={{@directMessages}}
        @inAdmin={{@currentChannel.isAdmin}}
        @onCreate={{@onCreate}}
      />

      <div class="concord-channel-header__channel">
        {{! "hamburger-dropdown" makes core's close-on-click-outside leave
            this button to toggle the panel itself. }}
        <DButton
          class="btn-flat concord-channel-header__menu hamburger-dropdown"
          @action={{this.toggleChannelList}}
          @icon="bars"
          @title="sidebar.title"
        />
        {{#if this.channel.name}}
          {{#if this.channel.back}}
            <a
              class="concord-channel-header__icon concord-channel-header__back"
              href={{this.channel.back.href}}
              title={{this.channel.back.title}}
            >
              {{dIcon "chevron-left"}}
            </a>
          {{else}}
            <span class="concord-channel-header__icon">
              {{dIcon this.channel.icon}}
            </span>
          {{/if}}
          <h1 class="concord-channel-header__name">
            {{#if this.channel.nameHref}}
              <a href={{this.channel.nameHref}}>{{this.channel.name}}</a>
            {{else}}
              {{this.channel.name}}
            {{/if}}
          </h1>
          {{#if this.channel.description}}
            <span class="concord-channel-header__description">
              {{#if this.channel.descriptionHref}}
                <a
                  href={{this.channel.descriptionHref}}
                >{{this.channel.description}}</a>
              {{else}}
                {{this.channel.description}}
              {{/if}}
            </span>
          {{/if}}
        {{/if}}

        <div class="concord-channel-header__actions">
          {{! The outlet core renders left of its header icons, so what's
              made for core's header shows here. }}
          <PluginOutlet @name="before-header-panel" />
          <div class="concord-before-header-panel-outlet">
            <PluginOutlet @name="concord-before-header-panel" />
          </div>
          {{#if this.showLanguageSwitcher}}
            <span class="concord-channel-header__language language-switcher">
              <LanguageSwitcher />
            </span>
          {{/if}}
          {{#if this.moreItems.length}}
            <DButton
              class="btn-flat concord-channel-header__more"
              @icon="ellipsis"
              @translatedTitle={{t "more"}}
              {{on "click" this.openMore}}
            />
          {{/if}}
          {{#each this.channel.actions as |headerAction|}}
            <DButton
              class={{dConcatClass
                "btn-flat"
                (if (this.isFolded headerAction) "--collapsible")
              }}
              data-action-id={{headerAction.id}}
              @action={{headerAction.action}}
              @icon={{headerAction.icon}}
              @translatedTitle={{headerAction.title}}
            />
          {{/each}}
          {{#if @memberList.available}}
            <DButton
              aria-pressed={{if this.memberListAction.active "true" "false"}}
              class={{dConcatClass
                "btn-flat"
                (if this.memberListAction.active "--active")
              }}
              data-action-id={{this.memberListAction.id}}
              @action={{this.memberListAction.action}}
              @icon={{this.memberListAction.icon}}
              @translatedTitle={{this.memberListAction.title}}
            />
          {{/if}}

          {{#unless @currentChannel.isAdmin}}
            <DButton
              class="btn-flat concord-channel-header__search"
              @icon="magnifying-glass"
              @title="search.title"
              {{on "click" this.openSearch}}
            />
          {{/unless}}

          {{#if this.currentUser}}
            {{! "user-menu-panel" makes core's close-on-click-outside leave
                this button to toggle the menu itself. }}
            <button
              class="btn-transparent concord-channel-header__user user-menu-panel"
              title={{i18n "user.avatar.header_title"}}
              type="button"
              {{on "click" this.toggleUserMenu}}
            >
              <Notifications />
            </button>
          {{/if}}

          {{#if @currentChannel.isAdmin}}
            <DButton
              class="btn-flat concord-channel-header__exit-admin"
              @href={{this.exitAdminHref}}
              @icon="xmark"
              @translatedTitle={{t "exit_admin"}}
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
