import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ChangeReplyTo extends Component {
  @tracked postNumber = this.args.model.currentPostNumber ?? "";
  @tracked flash;

  get maxPostNumber() {
    return this.args.model.editingPostNumber - 1;
  }

  get submitDisabled() {
    const n = parseInt(this.postNumber, 10);
    if (isNaN(n) || n <= 0) {
      return true;
    }
    if (n >= this.args.model.editingPostNumber) {
      return true;
    }
    return false;
  }

  @action
  updatePostNumber(event) {
    this.postNumber = event.target.value;
    this.flash = null;
  }

  get canRemove() {
    return !!this.args.model.currentPostNumber;
  }

  @action
  async submit() {
    const postNumber = parseInt(this.postNumber, 10);
    const postStream = this.args.model.topic?.postStream;

    try {
      let post = postStream?.postForPostNumber(postNumber);
      if (!post && postStream) {
        post = await postStream.loadPostByPostNumber(postNumber);
      }

      if (!post) {
        this.flash = i18n("composer.change_reply_to.not_found");
        return;
      }

      this.args.model.onSelect(post);
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  remove() {
    this.args.model.onSelect(null);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "composer.change_reply_to.title"}}
      @flash={{this.flash}}
      class="change-reply-to-modal"
    >
      <:body>
        <p>{{i18n
            "composer.change_reply_to.description"
            max=this.maxPostNumber
          }}</p>
        <input
          type="number"
          min="1"
          max={{this.maxPostNumber}}
          value={{this.postNumber}}
          {{on "input" this.updatePostNumber}}
          aria-label={{i18n "composer.change_reply_to.post_number_label"}}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.submit}}
          @label="composer.change_reply_to.submit"
          @disabled={{this.submitDisabled}}
          class="btn-primary"
        />
        {{#if this.canRemove}}
          <DButton
            @action={{this.remove}}
            @label="composer.change_reply_to.remove"
            class="btn-danger"
          />
        {{/if}}
        <DButton @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
