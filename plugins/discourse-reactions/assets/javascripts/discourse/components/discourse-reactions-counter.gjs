import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { and } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
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
    data.reactions.uniq().forEach((reaction) => {
      this.getUsers(reaction);
    });
  }

  @bind
  getUsers(reactionValue) {
    return CustomReaction.findReactionUsers(this.args.post.id, {
      reactionValue,
    }).then((response) => {
      response.reaction_users.forEach((reactionUser) => {
        this.reactionsUsers[reactionUser.id] = reactionUser.users;
      });

      this.args.updatePopperPosition();
    });
  }

  @action
  mouseDown(event) {
    event.stopImmediatePropagation();
    return false;
  }

  @action
  mouseUp(event) {
    event.stopImmediatePropagation();
    return false;
  }

  @action
  click(event) {
    if (event.target.closest("[data-user-card]")) {
      return;
    }

    this.args.cancelCollapse();

    if (!this.capabilities.touch || !this.site.mobileView) {
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
      {{on "mousedown" this.mouseDown}}
      {{on "mouseup" this.mouseUp}}
      {{closeOnClickOutside this.clickOutside (hash)}}
      {{on "touchstart" this.touchStart}}
      {{on "pointerover" this.pointerOver}}
      {{on "pointerout" this.pointerOut}}
      {{on "click" this.click}}
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

        <span class="reactions-counter">
          {{@post.reaction_users_count}}
        </span>

        {{#if (and @post.yours this.onlyOneMainReaction)}}
          <div class="discourse-reactions-reaction-button my-likes">
            <button
              type="button"
              class="btn-toggle-reaction-like btn-icon no-text reaction-button"
            >
              {{icon this.siteSettings.discourse_reactions_like_icon}}
            </button>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
