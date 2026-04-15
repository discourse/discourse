import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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
import DiscourseReactionsUsersPopup from "./discourse-reactions-users-popup";

export default class DiscourseReactionsCounter extends Component {
  @service capabilities;
  @service siteSettings;

  @tracked usersPopupExpanded = false;

  reactionsUsers = trackedObject();

  #scrollHandler = null;

  get elementId() {
    return `discourse-reactions-counter-${this.args.post.id}-${
      this.args.position || "right"
    }`;
  }

  get referenceElement() {
    return document.getElementById(this.elementId);
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

    this.args.updatePopover();
  }

  @action
  mouseDown(event) {
    event.stopImmediatePropagation();
  }

  @action
  mouseUp(event) {
    event.stopImmediatePropagation();
  }

  @action
  keyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.click(event);
    } else if (event.key === "Escape") {
      if (this.usersPopupExpanded) {
        event.stopPropagation();
        this.#closePopup();
        document.getElementById(this.elementId)?.focus();
      } else if (this.args.statePanelExpanded) {
        event.stopPropagation();
        this.args.collapseStatePanel();
        document.getElementById(this.elementId)?.focus();
      }
    }
  }

  @action
  click(event) {
    if (event.target.closest("[data-user-card]")) {
      return;
    }

    if (event.target.closest(".post-users-popup")) {
      return;
    }

    event.stopPropagation();
    event.preventDefault();

    if (this.usersPopupExpanded) {
      this.#closePopup();
    } else {
      this.#openPopup();
    }
  }

  @action
  clickOutside() {
    if (this.usersPopupExpanded) {
      this.#closePopup();
    } else if (this.args.statePanelExpanded) {
      this.args.collapseAllPanels();
    }
  }

  @action
  touchStart(event) {
    if (
      event.target.classList.contains("show-users") ||
      event.target.classList.contains("avatar")
    ) {
      return true;
    }

    if (event.target.closest(".post-users-popup")) {
      return true;
    }

    if (this.capabilities.touch) {
      event.stopPropagation();
      event.preventDefault();

      if (this.usersPopupExpanded) {
        this.#closePopup();
      } else {
        this.#openPopup();
      }
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
    if (event.pointerType !== "mouse" || this.usersPopupExpanded) {
      return;
    }

    this.args.cancelCollapse();
  }

  @action
  pointerOut(event) {
    if (event.pointerType !== "mouse" || this.usersPopupExpanded) {
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

  #openPopup() {
    if (this.args.statePanelExpanded) {
      this.args.collapseStatePanel();
    }
    this.usersPopupExpanded = true;
    this.#scrollHandler = () => this.#closePopup();
    window.addEventListener("scroll", this.#scrollHandler, {
      once: true,
      passive: true,
    });
  }

  #closePopup() {
    this.usersPopupExpanded = false;
    if (this.#scrollHandler) {
      window.removeEventListener("scroll", this.#scrollHandler);
      this.#scrollHandler = null;
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive no-pointer-down-event-binding }}
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

        {{#if this.usersPopupExpanded}}
          <DiscourseReactionsUsersPopup
            @post={{@post}}
            @referenceElement={{this.referenceElement}}
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
