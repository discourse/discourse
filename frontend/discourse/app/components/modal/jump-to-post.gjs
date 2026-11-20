import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDatePicker from "discourse/ui-kit/d-date-picker";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class JumpToPost extends Component {
  @tracked postNumber;
  @tracked postDate;

  get filteredPostsCount() {
    return this.args.model.topic.postStream.filteredPostsCount;
  }

  @action
  jump() {
    if (this.postNumber) {
      this._jumpToIndex(this.filteredPostsCount, this.postNumber);
    } else if (this.postDate) {
      this._jumpToDate(this.postDate);
    }
  }

  _jumpToIndex(postsCounts, postNumber) {
    const where = Math.min(postsCounts, Math.max(1, parseInt(postNumber, 10)));
    this.args.model.jumpToIndex(where);
    this.args.closeModal();
  }

  _jumpToDate(date) {
    this.args.model.jumpToDate(date);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="jump-to-post-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "topic.progress.jump_prompt_long"}}
    >
      <:body>
        <div class="jump-to-post-form">
          <div class="jump-to-post-control">
            <span class="index">#</span>
            <Input
              autofocus="true"
              id="post-jump"
              @type="number"
              @value={{this.postNumber}}
            />
            <span class="input-hint-text post-number">
              {{i18n
                "topic.progress.jump_prompt_of"
                count=this.filteredPostsCount
              }}
            </span>
          </div>

          <div class="separator">
            <span class="text">
              {{i18n "topic.progress.jump_prompt_or"}}
            </span>
            <hr class="right" />
          </div>

          <div class="jump-to-date-control">
            <span class="input-hint-text post-date">
              {{i18n "topic.progress.jump_prompt_to_date"}}
            </span>
            <DDatePicker
              class="date-input"
              id="post-date"
              @defaultDate="YYYY-MM-DD"
              @value={{this.postDate}}
            />
          </div>
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-primary"
          type="submit"
          @action={{this.jump}}
          @label="composer.modal_ok"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
