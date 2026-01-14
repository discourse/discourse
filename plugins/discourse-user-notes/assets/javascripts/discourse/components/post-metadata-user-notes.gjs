import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import emoji from "discourse/helpers/emoji";
import { showUserNotes, updatePostUserNotesCount } from "../lib/user-notes";

export default class PostMetadataUserNotes extends Component {
  @service siteSettings;
  @service store;

  @action
  showNotes() {
    showUserNotes(
      this.store,
      this.args.post.user_id,
      (count) => updatePostUserNotesCount(this.args.post, count),
      {
        postId: this.args.post.id,
      }
    );
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <span class="user-notes-icon" {{on "click" this.showNotes}}>
      {{#if this.siteSettings.enable_emoji}}
        {{emoji "memo"}}
      {{else}}
        {{icon "pen-to-square"}}
      {{/if}}
    </span>
  </template>
}
