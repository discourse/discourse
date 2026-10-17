import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import I18n, { i18n } from "discourse-i18n";

const ACTIONS = ["delete", "delete_all", "delete_replies", "edit", "none"];

export default class AdminPenaltyPostAction extends Component {
  @tracked confirmDeleteAll = false;

  get editing() {
    return this.args.postAction === "edit";
  }

  get deletingAll() {
    return this.args.postAction === "delete_all";
  }

  get penaltyActions() {
    const allActions = ACTIONS.map((id) => ({
      id,
      name: i18n(`admin.user.penalty_post_${id}`),
    }));

    // Remove "delete all" option for users at or above the configured trust level
    // For now the trust level is static, add a site setting later if we want users to be able to modify this
    if (this.args.user.trust_level >= 2) {
      return allActions.filter((act) => act.id !== "delete_all");
    }

    return allActions;
  }

  get topicsCount() {
    return this.args.user.topic_count;
  }

  get repliesCount() {
    return this.args.user.post_count - this.args.user.topic_count;
  }

  get readyToDeleteAll() {
    return this.deletingAll && this.confirmDeleteAll;
  }

  get deleteAllMessage() {
    return I18n.messageFormat(
      "admin.user.penalty_post_delete_all_confirmation_MF",
      {
        TOPICS: this.topicsCount,
        REPLIES: this.repliesCount,
      }
    );
  }

  @action
  toggleConfirmDeleteAll(event) {
    this.confirmDeleteAll = event.target.checked;

    this.args.onDeleteAllPostsReady?.(this.readyToDeleteAll);
  }

  <template>
    <div ...attributes>
      <div class="penalty-post-controls">
        <label>
          <div class="penalty-post-label">
            {{trustHTML (i18n "admin.user.penalty_post_actions")}}
          </div>
        </label>
        <ComboBox
          @content={{this.penaltyActions}}
          @onChange={{@onChangePostAction}}
          @value={{@postAction}}
        />
      </div>

      {{#if this.editing}}
        <div class="penalty-post-edit">
          <textarea
            class="post-editor"
            value={{@postEdit}}
            {{dAutoFocus preventScroll=false}}
            {{on "input" (withEventValue @onChangePostEdit)}}
          />
        </div>
      {{/if}}

      {{#if this.deletingAll}}
        <label>
          <Input
            @checked={{this.confirmDeleteAll}}
            @type="checkbox"
            {{on "click" this.toggleConfirmDeleteAll}}
          />
          {{trustHTML this.deleteAllMessage}}
        </label>
      {{/if}}
    </div>
  </template>
}
