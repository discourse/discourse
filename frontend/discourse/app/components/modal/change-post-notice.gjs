import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import withEventValue from "discourse/helpers/with-event-value";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class ChangePostNoticeModal extends Component {
  @service currentUser;

  @tracked notice = this.args.model.post.notice?.raw ?? "";
  @tracked saving = false;

  resolve = this.args.model.resolve;
  reject = this.args.model.reject;

  get post() {
    return this.args.model.post;
  }

  get disabled() {
    return (
      this.saving ||
      isEmpty(this.notice) ||
      this.notice === this.post.notice?.raw
    );
  }

  @action
  saveNotice() {
    this.setNotice(this.notice);
  }

  @action
  deleteNotice() {
    this.setNotice();
  }

  @action
  setNotice(notice) {
    const { resolve, reject } = this;

    this.saving = true;
    this.resolve = null;
    this.reject = null;

    this.post
      .updatePostField("notice", notice)
      .then((response) => {
        if (notice) {
          return response.cooked_notice;
        }
      })
      .then((cooked) => {
        this.post.set(
          "notice",
          cooked
            ? {
                type: "custom",
                raw: notice,
                cooked: cooked.toString(),
              }
            : null
        );
        this.post.set("noticeCreatedByUser", this.currentUser);
      })
      .then(resolve, reject)
      .finally(() => this.args.closeModal());
  }

  <template>
    <DModal
      class="change-post-notice-modal"
      @closeModal={{@closeModal}}
      @title={{if
        @model.post.notice
        (i18n "post.controls.change_post_notice")
        (i18n "post.controls.add_post_notice")
      }}
    >
      <:body>
        <form>
          <textarea
            value={{this.notice}}
            {{preventScrollOnFocus}}
            {{on "input" (withEventValue (fn (mut this.notice)))}}
          />
        </form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{fn this.setNotice this.notice}}
          @disabled={{this.disabled}}
          @label={{if this.saving "saving" "save"}}
        />
        {{#if @model.post.notice}}
          <DButton
            class="btn-danger"
            @action={{this.setNotice}}
            @disabled={{this.saving}}
            @label="post.controls.delete_post_notice"
          />
        {{/if}}
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
