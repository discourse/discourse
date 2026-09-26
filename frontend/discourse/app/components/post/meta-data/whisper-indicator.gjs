import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SiteService from "discourse/services/site";

export default class PostMetaDataWhisperIndicator extends Component {
  @service(() => SiteService) site;

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
      {{dIcon "far-eye-slash"}}
    </div>
  </template>
}
