import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DiscourseReactionsList from "./discourse-reactions-list";
import DiscourseReactionsUsersMenu from "./discourse-reactions-users-menu";

const MENU_IDENTIFIER = "discourse-reactions-users-menu";

export default class DiscourseReactionsCounter extends Component {
  @service menu;
  @service siteSettings;

  get elementId() {
    return `discourse-reactions-counter-${this.args.post.id}-${
      this.args.position || "right"
    }`;
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
      this.#toggleMenu(event.currentTarget);
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
    this.#toggleMenu(event.currentTarget);
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

  #toggleMenu(trigger) {
    this.menu.show(trigger, {
      identifier: MENU_IDENTIFIER,
      component: DiscourseReactionsUsersMenu,
      modalForMobile: true,
      closeOnScroll: true,
      arrow: true,
      placement: "bottom",
      offset: 15,
      data: { post: this.args.post },
    });
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
  </template>
}
