import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class ChangePostNoticeModal extends Component {
  @service currentUser;

  @tracked post = this.args.model.post;
  @tracked notice = this.args.model.post.notice?.raw ?? "";
  @tracked saving = false;

  resolve = this.args.model.resolve;
  reject = this.args.model.reject;

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
      @title={{if
        @model.post.notice
        (i18n "post.controls.change_post_notice")
        (i18n "post.controls.add_post_notice")
      }}
      @closeModal={{@closeModal}}
      class="change-post-notice-modal"
    >
      <:body>
        <form>
          <textarea
            value={{this.notice}}
            {{on "input" (withEventValue (fn (mut this.notice)))}}
          />
        </form>
      </:body>
      <:footer>
        <DButton
          @label={{if this.saving "saving" "save"}}
          @action={{fn this.setNotice this.notice}}
          @disabled={{this.disabled}}
          class="btn-primary"
        />
        {{#if @model.post.notice}}
          <DButton
            @label="post.controls.delete_post_notice"
            @action={{this.setNotice}}
            @disabled={{this.saving}}
            class="btn-danger"
          />
        {{/if}}
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
