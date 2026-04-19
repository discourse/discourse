import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { i18n } from "discourse-i18n";
import DiscourseReactionsList from "./discourse-reactions-list";
import DiscourseReactionsUsersPopup from "./discourse-reactions-users-popup";

export default class DiscourseReactionsCounter extends Component {
  @service capabilities;
  @service siteSettings;

  @tracked usersPopupExpanded = false;

  #scrollHandler = null;

  get elementId() {
    return `discourse-reactions-counter-${this.args.post.id}-${
      this.args.position || "right"
    }`;
  }

  get referenceElement() {
    return document.getElementById(this.elementId);
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
      if (this.usersPopupExpanded) {
        this.#closePopup();
      } else {
        this.#openPopup();
      }
    } else if (event.key === "Escape" && this.usersPopupExpanded) {
      event.stopPropagation();
      this.#closePopup();
      document.getElementById(this.elementId)?.focus();
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

  get counterAriaLabel() {
    return i18n("discourse_reactions.counter.aria_label", {
      count: this.args.post.reaction_users_count,
    });
  }

  #openPopup() {
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
      {{on "click" this.click}}
      {{on "keydown" this.keyDown}}
    >
      {{#if @post.reaction_users_count}}
        <DiscourseReactionsList {{on "click" this.click}} @post={{@post}} />

        <span class="reactions-counter" aria-hidden="true">
          {{@post.reaction_users_count}}
        </span>

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
