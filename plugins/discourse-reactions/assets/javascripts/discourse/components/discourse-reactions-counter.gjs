import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CustomReaction from "../models/discourse-reactions-custom-reaction";
import DiscourseReactionsList from "./discourse-reactions-list";
import DiscourseReactionsStatePanel from "./discourse-reactions-state-panel";
import DiscourseReactionsUsersMenu from "./discourse-reactions-users-menu";

const MENU_IDENTIFIER = "discourse-reactions-users-menu";

export default class DiscourseReactionsCounter extends Component {
  @service capabilities;
  @service menu;
  @service site;
  @service siteSettings;

  reactionsUsers = trackedObject();

  get useNewMenu() {
    return this.siteSettings.enable_new_post_reactions_menu;
  }

  get elementId() {
    return `discourse-reactions-counter-${this.args.post.id}-${
      this.args.position || "right"
    }`;
  }

  get hasOpenMenuForThisPost() {
    const menu = this.menu.getByIdentifier(MENU_IDENTIFIER);
    return (
      !!menu?.expanded && menu.options.data?.post?.id === this.args.post.id
    );
  }

  reactionsChanged(data) {
    uniqueItemsFromArray(data.reactions).forEach((reaction) => {
      this.getUsers(reaction);
    });
  }

  @bind
  async getUsers(reactionValue) {
    const response = await CustomReaction.findReactionUsers(this.args.post.id, {
      reactionValue,
    });

    response.reaction_users.forEach((reactionUser) => {
      this.reactionsUsers[reactionUser.id] = reactionUser.users;
    });

    this.args.updatePopover?.();
  }

  @action
  mouseDown(event) {
    event.stopImmediatePropagation();
  }

  @action
  pointerDown(event) {
    if (!this.useNewMenu) {
      return;
    }

    if (this.hasOpenMenuForThisPost) {
      event.stopPropagation();
    }
  }

  @action
  mouseUp(event) {
    event.stopImmediatePropagation();
  }

  @action
  keyDown(event) {
    if (this.useNewMenu) {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        this.#toggleMenu(event.currentTarget);
      }
      return;
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.click(event);
    } else if (event.key === "Escape" && this.args.statePanelExpanded) {
      event.stopPropagation();
      this.args.collapseStatePanel();
      document.getElementById(this.elementId)?.focus();
    }
  }

  @action
  click(event) {
    if (event.target.closest("[data-user-card]")) {
      return;
    }

    if (this.useNewMenu) {
      if (event.target.closest(".post-users-popup")) {
        return;
      }

      event.stopPropagation();
      event.preventDefault();
      const reactionEl = event.target.closest(
        ".discourse-reactions-list-emoji[data-reaction-id]"
      );
      const reactionId = reactionEl?.dataset.reactionId;

      if (this.hasOpenMenuForThisPost) {
        this.#switchMenuFilter(reactionId ?? "all");
        return;
      }

      this.#toggleMenu(event.currentTarget, reactionId);
      return;
    }

    this.args.cancelCollapse();

    if (!this.capabilities.touch || this.site.desktopView) {
      event.stopPropagation();
      event.preventDefault();

      if (!this.args.statePanelExpanded) {
        this.getUsers();
      }

      this.toggleStatePanel(event);
    }
  }

  @action
  clickOutside() {
    if (this.args.statePanelExpanded) {
      this.args.collapseAllPanels();
    }
  }

  @action
  touchStart(event) {
    if (this.useNewMenu) {
      return;
    }

    this.args.cancelCollapse();

    if (
      event.target.classList.contains("show-users") ||
      event.target.classList.contains("avatar")
    ) {
      return true;
    }

    if (this.args.statePanelExpanded) {
      event.stopPropagation();
      event.preventDefault();
      return;
    }

    if (this.capabilities.touch) {
      event.stopPropagation();
      event.preventDefault();
      this.getUsers();
      this.toggleStatePanel(event);
    }
  }

  get classes() {
    const classes = [];
    const mainReaction =
      this.siteSettings.discourse_reactions_reaction_for_like;

    const { post } = this.args;

    if (
      post.reactions &&
      post.reactions.length === 1 &&
      post.reactions[0].id === mainReaction
    ) {
      classes.push("only-like");
    }

    if (post.reaction_users_count > 0) {
      classes.push("discourse-reactions-counter");
    }

    return classes.join(" ");
  }

  toggleStatePanel() {
    if (!this.args.statePanelExpanded) {
      this.args.expandStatePanel();
    } else {
      this.args.collapseStatePanel();
    }
  }

  @action
  pointerOver(event) {
    if (this.useNewMenu) {
      return;
    }

    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.cancelCollapse();
  }

  @action
  pointerOut(event) {
    if (this.useNewMenu) {
      return;
    }

    if (event.pointerType !== "mouse") {
      return;
    }

    if (!event.relatedTarget?.closest(`#${this.elementId}`)) {
      this.args.scheduleCollapse("collapseStatePanel");
    }
  }

  get counterAriaLabel() {
    return i18n("discourse_reactions.counter.aria_label", {
      count: this.args.post.reaction_users_count,
    });
  }

  get onlyOneMainReaction() {
    return (
      this.args.post.reactions?.length === 1 &&
      this.args.post.reactions[0].id ===
        this.siteSettings.discourse_reactions_reaction_for_like
    );
  }

  #switchMenuFilter(filter) {
    document
      .querySelector(
        `[data-identifier="${MENU_IDENTIFIER}"] [data-reaction-filter="${filter}"]`
      )
      ?.click();
  }

  #toggleMenu(trigger, initialFilter = null) {
    const virtualElement = {
      getBoundingClientRect: () => trigger.getBoundingClientRect(),
    };

    this.menu.show(virtualElement, {
      identifier: MENU_IDENTIFIER,
      component: DiscourseReactionsUsersMenu,
      modalForMobile: true,
      closeOnScroll: true,
      arrow: true,
      placement: "bottom",
      offset: 15,
      data: { post: this.args.post, initialFilter },
    });
  }

  <template>
    {{! template-lint-disable no-invalid-interactive no-pointer-down-event-binding }}
    {{#if this.useNewMenu}}
      <div
        id={{this.elementId}}
        class={{this.classes}}
        role="button"
        tabindex="0"
        aria-label={{this.counterAriaLabel}}
        {{on "mousedown" this.mouseDown}}
        {{on "mouseup" this.mouseUp}}
        {{on "pointerdown" this.pointerDown}}
        {{on "click" this.click}}
        {{on "keydown" this.keyDown}}
      >
        {{#if @post.reaction_users_count}}
          <DiscourseReactionsList @post={{@post}} />

          <span class="reactions-counter" aria-hidden="true">
            {{@post.reaction_users_count}}
          </span>
        {{/if}}
      </div>
    {{else}}
      <div
        id={{this.elementId}}
        class={{this.classes}}
        role="button"
        tabindex="0"
        aria-label={{this.counterAriaLabel}}
        {{on "mousedown" this.mouseDown}}
        {{on "mouseup" this.mouseUp}}
        {{closeOnClickOutside this.clickOutside}}
        {{on "touchstart" this.touchStart}}
        {{on "pointerover" this.pointerOver}}
        {{on "pointerout" this.pointerOut}}
        {{on "click" this.click}}
        {{on "keydown" this.keyDown}}
      >
        {{#if @post.reaction_users_count}}
          <DiscourseReactionsStatePanel
            @post={{@post}}
            @reactionsUsers={{this.reactionsUsers}}
            @statePanelExpanded={{@statePanelExpanded}}
            @scheduleCollapse={{@scheduleCollapse}}
            @cancelCollapse={{@cancelCollapse}}
          />

          {{#unless this.onlyOneMainReaction}}
            <DiscourseReactionsList
              {{on "click" this.click}}
              @post={{@post}}
              @reactionsUsers={{this.reactionsUsers}}
              @getUsers={{this.getUsers}}
            />
          {{/unless}}

          <span class="reactions-counter" aria-hidden="true">
            {{@post.reaction_users_count}}
          </span>

          {{#if (and @post.yours this.onlyOneMainReaction)}}
            <div class="discourse-reactions-reaction-button my-likes">
              <DButton
                class="btn-toggle-reaction-like btn-flat btn-icon no-text reaction-button"
                @translatedTitle={{this.counterAriaLabel}}
                @icon={{this.siteSettings.discourse_reactions_like_icon}}
              />
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
