import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import DatePicker from "discourse/components/date-picker";
import i18n from "discourse-common/helpers/i18n";

export default class JumpToPost extends Component {
  @tracked postNumber;
  @tracked postDate;

  get filteredPostsCount() {
    return this.args.model.topic.postStream.filteredPostsCount;
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

  @action
  jump() {
    if (this.postNumber) {
      this._jumpToIndex(this.filteredPostsCount, this.postNumber);
    } else if (this.postDate) {
      this._jumpToDate(this.postDate);
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "topic.progress.jump_prompt_long"}}
      class="jump-to-post-modal"
    >
      <:body>
        <div class="jump-to-post-form">
          <div class="jump-to-post-control">
            <span class="index">#</span>
            <Input
              @value={{this.postNumber}}
              @type="number"
              autofocus="true"
              id="post-jump"
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
            <DatePicker
              @value={{this.postDate}}
              @defaultDate="YYYY-MM-DD"
              id="post-date"
              class="date-input"
            />
          </div>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.jump}}
          @label="composer.modal_ok"
          type="submit"
          class="btn-primary"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
