import Component from "@glimmer/component";
import { service } from "@ember/service";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { i18n } from "discourse-i18n";

export default class AiImageCaptionLoader extends Component {
  @service imageCaptionPopup;

  <template>
    {{#if this.imageCaptionPopup.showAutoCaptionLoader}}
      <div class="auto-image-caption-loader">
        {{loadingSpinner size="small"}}
        <span>{{i18n
            "discourse_ai.ai_helper.image_caption.automatic_caption_loading"
          }}</span>
      </div>
    {{/if}}
  </template>
}
