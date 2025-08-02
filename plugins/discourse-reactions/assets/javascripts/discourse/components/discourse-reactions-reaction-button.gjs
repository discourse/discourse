import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import icon from "discourse/helpers/d-icon";
import { emojiUrlFor } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

export default class ReactionsReactionButton extends Component {
  @service capabilities;
  @service siteSettings;
  @service site;
  @service currentUser;

  @action
  click() {
    this.args.cancelCollapse();

    const currentUserReaction = this.args.post.current_user_reaction;
    if (!this.capabilities.touch || !this.site.mobileView) {
      this.args.toggleFromButton({
        reaction: currentUserReaction
          ? currentUserReaction.id
          : this.siteSettings.discourse_reactions_reaction_for_like,
      });
    }
  }

  @action
  pointerOver(event) {
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.cancelCollapse();

    const likeAction = this.args.post.likeAction;
    const currentUserReaction = this.args.post.current_user_reaction;
    if (
      currentUserReaction &&
      !currentUserReaction.can_undo &&
      (!likeAction || isBlank(likeAction.can_undo))
    ) {
      return;
    }

    this.args.toggleReactions(event);
  }

  @action
  pointerOut(event) {
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.cancelExpand();
    this.args.scheduleCollapse("collapseReactionsPicker");
  }

  get title() {
    if (!this.currentUser) {
      return i18n("discourse_reactions.main_reaction.unauthenticated");
    }

    const likeAction = this.args.post.likeAction;
    if (!likeAction) {
      return null;
    }

    let title;
    let options;
    const currentUserReaction = this.args.post.current_user_reaction;

    if (likeAction.canToggle && isBlank(likeAction.can_undo)) {
      title = "discourse_reactions.main_reaction.add";
    }

    if (likeAction.canToggle && likeAction.can_undo) {
      title = "discourse_reactions.main_reaction.remove";
    }

    if (!likeAction.canToggle) {
      title = "discourse_reactions.main_reaction.cant_remove";
    }

    if (
      currentUserReaction &&
      currentUserReaction.can_undo &&
      isBlank(likeAction.can_undo)
    ) {
      title = "discourse_reactions.picker.remove_reaction";
      options = { reaction: currentUserReaction.id };
    }

    if (
      currentUserReaction &&
      !currentUserReaction.can_undo &&
      isBlank(likeAction.can_undo)
    ) {
      title = "discourse_reactions.picker.cant_remove_reaction";
    }

    return options ? i18n(title, options) : i18n(title);
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="discourse-reactions-reaction-button"
      {{on "click" this.click}}
      {{on "pointerover" this.pointerOver}}
      {{on "pointerout" this.pointerOut}}
      title={{this.title}}
    >
      {{#if @post.current_user_used_main_reaction}}
        <button
          type="button"
          class="btn-toggle-reaction-like btn-icon no-text reaction-button"
          title={{this.title}}
        >
          {{icon this.siteSettings.discourse_reactions_like_icon}}
        </button>
      {{else if @post.current_user_reaction}}
        <button
          type="button"
          class="btn-icon no-text reaction-button"
          title={{this.title}}
        >
          <img
            class="btn-toggle-reaction-emoji reaction-button"
            src={{emojiUrlFor @post.current_user_reaction.id}}
            alt={{concat ":" @post.current_user_reaction.id}}
          />
        </button>
      {{else}}
        <button
          type="button"
          class="btn-toggle-reaction-like btn-icon no-text reaction-button"
          title={{this.title}}
        >
          {{icon
            (concat "far-" this.siteSettings.discourse_reactions_like_icon)
          }}
        </button>
      {{/if}}
    </div>
  </template>
}
