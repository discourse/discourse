import Component from "@glimmer/component";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default class PostMetaDataLanguage extends Component {
  @service languageNameLookup;

  get language() {
    const lang = this.args.post?.language;
    return this.languageNameLookup.getLanguageName(lang);
  }

  get outdated() {
    return this.args.post?.localization_outdated;
  }

  get tooltip() {
    const i18nKey = this.outdated
      ? "post.original_language_and_outdated"
      : "post.original_language";

    return i18n(i18nKey, { language: this.language });
  }

  <template>
    <div class="post-info post-language">
      <DTooltip
        class={{if this.outdated "heatmap-low"}}
        @identifier="post-language"
        @icon="language"
      >
        <:content>
          <div>{{this.tooltip}}</div>
          <div class="post-language__disclaimer">{{i18n
              "post.ai_translation_disclaimer"
            }}</div>
        </:content>
      </DTooltip>
    </div>
  </template>
}
