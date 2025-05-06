import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class PostMetaDataTranslationIndicator extends Component {
  get icon() {
    // Can be passed as string directly
    return "globe";
  }

  get label() {
    // TODO get proper number
    return "1";
  }

  get title() {
    // TODO return i18n
    return "Translations";
  }

  <template>
    <div class="post-info translations">
      <DButton
        class="btn-flat"
        @icon={{this.icon}}
        @translatedLabel={{this.label}}
        @translatedTitle={{this.title}}
      />
    </div>
  </template>
}
