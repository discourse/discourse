import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";
import {
  isAiCreditLimitError,
  popupAiCreditLimitError,
} from "../../lib/ai-errors";
import ThumbnailSuggestionItem from "../thumbnail-suggestion-item";

export default class ThumbnailSuggestions extends Component {
  @tracked loading = false;
  @tracked selectedImages = [];
  @tracked thumbnails = null;

  constructor() {
    super(...arguments);

    this.findThumbnails();
  }

  get isDisabled() {
    return this.selectedImages.length === 0;
  }

  async findThumbnails() {
    this.loading = true;
    try {
      const thumbnails = await ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          mode: this.args.model.mode,
          text: this.args.model.selectedText,
          force_default_locale: true,
        },
      });

      this.thumbnails = thumbnails.thumbnails;
    } catch (error) {
      if (isAiCreditLimitError(error)) {
        this.args.closeModal();
        popupAiCreditLimitError(error);
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  addSelection(selection) {
    const thumbnailMarkdown = `![${selection.original_filename}|${selection.width}x${selection.height}](${selection.short_url})`;
    this.selectedImages = [...this.selectedImages, thumbnailMarkdown];
  }

  @action
  removeSelection(selection) {
    const thumbnailMarkdown = `![${selection.original_filename}|${selection.width}x${selection.height}](${selection.short_url})`;

    this.selectedImages = this.selectedImages.filter((thumbnail) => {
      if (thumbnail !== thumbnailMarkdown) {
        return thumbnail;
      }
    });
  }

  @action
  appendSelectedImages() {
    const imageMarkdown = "\n\n" + this.selectedImages.join("\n");

    const dEditorInput = document.querySelector(".d-editor-input");
    dEditorInput.setSelectionRange(
      dEditorInput.value.length,
      dEditorInput.value.length
    );
    dEditorInput.focus();
    document.execCommand("insertText", false, imageMarkdown);
    this.args.closeModal();
  }

  @action
  regenerateThumbnails() {
    this.selectedImages = [];
    this.thumbnails = null;
    this.findThumbnails();
  }

  <template>
    <DModal
      class="thumbnail-suggestions-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.ai_helper.thumbnail_suggestions.title"}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          <div class="ai-thumbnail-suggestions">
            {{#each this.thumbnails as |thumbnail|}}
              <ThumbnailSuggestionItem
                @addSelection={{this.addSelection}}
                @removeSelection={{this.removeSelection}}
                @thumbnail={{thumbnail}}
              />
            {{/each}}
          </div>
        </DConditionalLoadingSpinner>
      </:body>

      <:footer>
        <DButton
          class="btn-primary create"
          @action={{this.appendSelectedImages}}
          @disabled={{this.isDisabled}}
          @label="save"
        />
        <DModalCancel @close={{@closeModal}} />
        <DButton
          class="regenerate"
          @action={{this.regenerateThumbnails}}
          @disabled={{this.loading}}
          @icon="arrows-rotate"
          @label="discourse_ai.ai_helper.thumbnail_suggestions.try_again"
        />
      </:footer>
    </DModal>
  </template>
}
