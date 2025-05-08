import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class PostMetaDataLanguage extends Component {
  get tooltip() {
    // once we switch to glimmer, we can remove `this.args.data.language`
    const language = this.args.data?.language || this.args.post?.language;
    return i18n("post.original_language", {
      language,
    });
  }

  <template>
    <div class="post-info post-language">
      <DTooltip
        @identifier="post-language"
        @icon="language"
        @content={{this.tooltip}}
      />
    </div>
  </template>
}
