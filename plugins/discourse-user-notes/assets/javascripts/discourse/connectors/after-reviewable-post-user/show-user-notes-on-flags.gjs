import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { emojiUrlFor } from "discourse/lib/text";
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
          @translatedTitle={{i18n "user_notes.show" count=this.userNotesCount}}
          @action={{this.showUserNotes}}
          class="btn-flat"
        >
          {{#if this.siteSettings.enable_emoji}}
            <img
              src={{emojiUrlFor "memo"}}
              title={{i18n "user_notes.show" count=this.userNotesCount}}
              alt
              class="emoji"
            />
          {{else}}
            {{icon "pen-to-square"}}
          {{/if}}
        </DButton>
      {{/if}}
    </div>
  </template>
}
