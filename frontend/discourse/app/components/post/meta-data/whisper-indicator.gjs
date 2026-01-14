import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class PostMetaDataWhisperIndicator extends Component {
  @service site;

  get groups() {
    return this.site.whispers_allowed_groups_names;
  }

  get title() {
    if (this.groups?.length > 0) {
      return i18n("post.whisper_groups", {
        groupNames: this.groups.join(", "),
      });
    }

    return i18n("post.whisper");
  }

  <template>
    <div class="post-info whisper" title={{this.title}}>
      {{icon "far-eye-slash"}}
    </div>
  </template>
}
