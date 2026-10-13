import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { emojiUrlFor } from "discourse/lib/text";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { showUserNotes } from "../../lib/user-notes";

export default class ShowUserNotesOnFlags extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.user_notes_enabled && args.user;
  }

  @service store;
  @service siteSettings;

  @tracked
  userNotesCount = this.args.user.get("custom_fields.user_notes_count") || 0;

  @action
  showUserNotes() {
    showUserNotes(
      this.store,
      this.args.user.id,
      (count) => (this.userNotesCount = count)
    );
  }

  <template>
    <div class="after-reviewable-post-user-outlet show-user-notes-on-flags">
      {{#if this.userNotesCount}}
        <DButton
          class="btn-flat"
          @action={{this.showUserNotes}}
          @translatedTitle={{i18n "user_notes.show" count=this.userNotesCount}}
        >
          {{#if this.siteSettings.enable_emoji}}
            <img
              alt
              class="emoji"
              src={{emojiUrlFor "memo"}}
              title={{i18n "user_notes.show" count=this.userNotesCount}}
            />
          {{else}}
            {{dIcon "pen-to-square"}}
          {{/if}}
        </DButton>
      {{/if}}
    </div>
  </template>
}
