import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { cook } from "discourse/lib/text";

export default class ChangePostNoticeModal extends Component {
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
      .then(() => {
        if (notice) {
          return cook(notice, { features: { onebox: false } });
        }
      })
      .then((cooked) =>
        this.post.set(
          "notice",
          cooked
            ? {
                type: "custom",
                raw: notice,
                cooked: cooked.toString(),
              }
            : null
        )
      )
      .then(resolve, reject)
      .finally(() => this.args.closeModal());
  }
}
