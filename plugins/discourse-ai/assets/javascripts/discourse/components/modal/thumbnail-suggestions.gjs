import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
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
      @title={{i18n "discourse_ai.ai_helper.thumbnail_suggestions.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          <div class="ai-thumbnail-suggestions">
            {{#each this.thumbnails as |thumbnail|}}
              <ThumbnailSuggestionItem
                @thumbnail={{thumbnail}}
                @addSelection={{this.addSelection}}
                @removeSelection={{this.removeSelection}}
              />
            {{/each}}
          </div>
        </ConditionalLoadingSpinner>
      </:body>

      <:footer>
        <DButton
          @action={{this.appendSelectedImages}}
          @label="save"
          @disabled={{this.isDisabled}}
          class="btn-primary create"
        />
        <DModalCancel @close={{@closeModal}} />
        <DButton
          @action={{this.regenerateThumbnails}}
          @icon="arrows-rotate"
          @label="discourse_ai.ai_helper.thumbnail_suggestions.try_again"
          @disabled={{this.loading}}
          class="regenerate"
        />
      </:footer>
    </DModal>
  </template>
}
