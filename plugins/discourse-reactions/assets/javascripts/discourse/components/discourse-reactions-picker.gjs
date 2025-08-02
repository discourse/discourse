import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import emoji from "discourse/helpers/emoji";
import { i18n } from "discourse-i18n";

export default class DiscourseReactionsPicker extends Component {
  @service siteSettings;

  @action
  pointerOut(event) {
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.scheduleCollapse("collapseReactionsPicker");
  }

  @action
  pointerOver() {
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.cancelCollapse();
  }

  get reactionInfo() {
    const reactions = this.siteSettings.discourse_reactions_enabled_reactions
      .split("|")
      .filter(Boolean);

    if (
      !reactions.includes(
        this.siteSettings.discourse_reactions_reaction_for_like
      )
    ) {
      reactions.unshift(
        this.siteSettings.discourse_reactions_reaction_for_like
      );
    }

    const { post } = this.args;
    const currentUserReaction = post.current_user_reaction;

    return reactions.map((reaction) => {
      let isUsed;
      let canUndo;

      if (
        reaction === this.siteSettings.discourse_reactions_reaction_for_like
      ) {
        isUsed = post.current_user_used_main_reaction;
      } else {
        isUsed = currentUserReaction && currentUserReaction.id === reaction;
      }

      if (currentUserReaction) {
        canUndo = currentUserReaction.can_undo && post.likeAction.canToggle;
      } else {
        canUndo = post.likeAction.canToggle;
      }

      let title;
      let titleOptions;
      if (canUndo) {
        title = "discourse_reactions.picker.react_with";
        titleOptions = { reaction };
      } else {
        title = "discourse_reactions.picker.cant_remove_reaction";
      }

      return {
        id: reaction,
        title: i18n(title, titleOptions),
        canUndo,
        isUsed,
      };
    });
  }

  _getOptimalColsCount(count) {
    let x;
    const colsByRow = [5, 6, 7, 8];

    // if small count, just use it
    if (count < colsByRow[0]) {
      return count;
    }

    for (let index = 0; index < colsByRow.length; ++index) {
      const i = colsByRow[index];

      // if same as one of the max cols number, just use it
      let rest = count % i;
      if (rest === 0) {
        x = i;
        break;
      }

      // loop until we find a number limiting to the minimum the number
      // of empty cells
      if (index === 0) {
        x = i;
      } else {
        if (rest > count % (i - 1)) {
          x = i;
        }
      }
    }

    return x;
  }

  <template>
    <div
      class={{concatClass
        "discourse-reactions-picker"
        (if @reactionsPickerExpanded "is-expanded")
      }}
      {{on "pointerover" this.pointerOver}}
      {{on "pointerout" this.pointerOut}}
    >
      {{#if @reactionsPickerExpanded}}
        <div
          class="discourse-reactions-picker-container col-{{this._getOptimalColsCount
              this.reactionInfo.length
            }}"
        >
          {{#each this.reactionInfo as |reaction|}}
            <DButton
              class={{concatClass
                "pickable-reaction"
                reaction.id
                (if reaction.canUndo "can-undo")
                (if reaction.isUsed "is-used")
              }}
              data-reaction={{reaction.id}}
              @action={{fn
                @toggle
                (hash
                  reaction=reaction.id postId=@post.id canUndo=reaction.canUndo
                )
              }}
              @translatedTitle={{reaction.title}}
            >
              {{emoji reaction.id}}
            </DButton>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
