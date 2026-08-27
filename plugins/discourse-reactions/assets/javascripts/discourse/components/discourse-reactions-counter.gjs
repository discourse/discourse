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

  get expanded() {
    return this.menu.getByIdentifier(MENU_IDENTIFIER)?.id === this.elementId;
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
  click(event) {
    if (event.target.closest("[data-user-card]")) {
      return;
    }

    if (event.target.closest(".users-popup")) {
      return;
    }

    event.stopPropagation();
    event.preventDefault();
    this.#toggleMenu(event.currentTarget);
  }

  get classes() {
    const classes = ["discourse-reactions-counter"];
    const mainReaction =
      this.siteSettings.discourse_reactions_reaction_for_like;

    const { reactions } = this.args.post;

    if (
      reactions &&
      reactions.length === 1 &&
      reactions[0].id === mainReaction
    ) {
      classes.push("only-like");
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
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    {{#if @post.reaction_users_count}}
      <button
        id={{this.elementId}}
        type="button"
        class={{this.classes}}
        aria-label={{this.counterAriaLabel}}
        aria-haspopup="dialog"
        aria-expanded={{if this.expanded "true" "false"}}
        {{on "mousedown" this.mouseDown}}
        {{on "mouseup" this.mouseUp}}
        {{on "click" this.click}}
      >
        <DiscourseReactionsList @post={{@post}} />

        <span class="reactions-counter" aria-hidden="true">
          {{@post.reaction_users_count}}
        </span>
      </button>
    {{/if}}
  </template>
}
