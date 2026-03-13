import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CustomReaction from "../models/discourse-reactions-custom-reaction";
import DiscourseReactionsList from "./discourse-reactions-list";
import DiscourseReactionsStatePanel from "./discourse-reactions-state-panel";

export default class DiscourseReactionsCounter extends Component {
  @service capabilities;
  @service site;
  @service siteSettings;

  reactionsUsers = new TrackedObject();

  get elementId() {
    return `discourse-reactions-counter-${this.args.post.id}-${
      this.args.position || "right"
    }`;
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
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.cancelCollapse();
  }

  @action
  pointerOut(event) {
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
      {{/if}}
    </div>
  </template>
}
