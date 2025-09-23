import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class PostMetaDataLanguage extends Component {
  @service languageNameLookup;

  get language() {
    return this.languageNameLookup.getLanguageName(this.args.post?.language);
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
        @content={{this.tooltip}}
      />
    </div>
  </template>
}
