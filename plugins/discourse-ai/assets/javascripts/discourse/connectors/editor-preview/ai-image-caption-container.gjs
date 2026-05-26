import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DTextarea from "discourse/ui-kit/d-textarea";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class AiImageCaptionContainer extends Component {
  @service imageCaptionPopup;

  @action
  updateCaption(event) {
    event.preventDefault();
    this.imageCaptionPopup.newCaption = event.target.value;
  }

  @action
  saveCaption() {
    this.imageCaptionPopup.updateCaption();
    this.hidePopup();
  }

  @action
  resizeTextarea(target) {
    const style = window.getComputedStyle(target);

    // scrollbars will show based on scrollHeight alone
    // so we need to consider borders too
    const borderTopWidth = parseInt(style.borderTopWidth, 10);
    const borderBottomWidth = parseInt(style.borderBottomWidth, 10);

    target.scrollTop = 0;
    target.style.height = `${
      target.scrollHeight + borderTopWidth + borderBottomWidth
    }px`;
  }

  @action
  hidePopup() {
    this.imageCaptionPopup.showPopup = false;
    if (this.imageCaptionPopup._request) {
      this.imageCaptionPopup._request.abort();
      this.imageCaptionPopup._request = null;
      this.imageCaptionPopup.toggleLoadingState(false);
    }
  }

  <template>
    {{#if this.imageCaptionPopup.showPopup}}
      <div
        class="composer-popup education-message ai-caption-popup"
        {{willDestroy this.hidePopup}}
      >
        <DConditionalLoadingSpinner
          @condition={{this.imageCaptionPopup.loading}}
        >
          <DTextarea
            {{didInsert this.resizeTextarea}}
            {{didUpdate this.resizeTextarea this.imageCaptionPopup.newCaption}}
            @value={{this.imageCaptionPopup.newCaption}}
            {{on "change" this.updateCaption}}
            {{dAutoFocus}}
          />
        </DConditionalLoadingSpinner>

        <div class="actions">
          <DButton
            class="btn-primary"
            @label="discourse_ai.ai_helper.image_caption.save_caption"
            @icon="check"
            @action={{this.saveCaption}}
          />
          <DButton
            class="btn-flat cancel-request"
            @label="cancel"
            @action={{this.hidePopup}}
          />

          <span class="credits">
            {{dIcon "discourse-sparkles"}}
            <span>{{i18n "discourse_ai.ai_helper.image_caption.credits"}}</span>
          </span>
        </div>
      </div>
    {{/if}}
  </template>
}
