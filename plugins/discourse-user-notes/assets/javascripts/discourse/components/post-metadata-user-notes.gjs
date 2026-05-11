import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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
        {{dEmoji "memo"}}
      {{else}}
        {{dIcon "pen-to-square"}}
      {{/if}}
    </span>
  </template>
}
