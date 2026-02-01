/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import { tracked } from "@glimmer/tracking";
import Component, { Input, Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import discourseComputed, { afterRender } from "discourse/lib/decorators";
import ComboBox from "discourse/select-kit/components/combo-box";
import I18n, { i18n } from "discourse-i18n";

const ACTIONS = ["delete", "delete_all", "delete_replies", "edit", "none"];

export default class AdminPenaltyPostAction extends Component {
  @tracked confirmDeleteAll = false;

  postId = null;
  postAction = null;
  postEdit = null;

  @equal("postAction", "edit") editing;
  @equal("postAction", "delete_all") deletingAll;

  @discourseComputed
  penaltyActions() {
    const allActions = ACTIONS.map((id) => ({
      id,
      name: i18n(`admin.user.penalty_post_${id}`),
    }));

    // Remove "delete all" option for users at or above the configured trust level
    // For now the trust level is static, add a site setting later if we want users to be able to modify this
    if (this.user.trust_level >= 2) {
      return allActions.filter((act) => act.id !== "delete_all");
    }

    return allActions;
  }

  get topicsCount() {
    return this.user.topic_count;
  }

  get repliesCount() {
    return this.user.post_count - this.user.topic_count;
  }

  canSubmitDeleteAll() {
    return this.postAction === "delete_all" && this.confirmDeleteAll;
  }

  get readyToDeleteAll() {
    return this.canSubmitDeleteAll();
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
  penaltyChanged(postAction) {
    this.set("postAction", postAction);

    // If we switch to edit mode, jump to the edit textarea
    if (postAction === "edit") {
      this._focusEditTextarea();
    }
  }

  @action
  toggleConfirmDeleteAll(event) {
    this.set("confirmDeleteAll", event.target.checked);

    this.onDeleteAllPostsReady?.(this.readyToDeleteAll);
  }

  @afterRender
  _focusEditTextarea() {
    const elem = this.element;
    const body = elem.closest(".d-modal__body");
    body.scrollTo(0, body.clientHeight);
    elem.querySelector(".post-editor").focus();
  }

  <template>
    <div class="penalty-post-controls">
      <label>
        <div class="penalty-post-label">
          {{htmlSafe (i18n "admin.user.penalty_post_actions")}}
        </div>
      </label>
      <ComboBox
        @value={{this.postAction}}
        @content={{this.penaltyActions}}
        @onChange={{this.penaltyChanged}}
      />
    </div>

    {{#if this.editing}}
      <div class="penalty-post-edit">
        <Textarea @value={{this.postEdit}} class="post-editor" />
      </div>
    {{/if}}

    {{#if this.deletingAll}}
      <label>
        <Input
          @type="checkbox"
          @checked={{this.confirmDeleteAll}}
          {{on "click" this.toggleConfirmDeleteAll}}
        />
        {{htmlSafe this.deleteAllMessage}}
      </label>
    {{/if}}
  </template>
}
