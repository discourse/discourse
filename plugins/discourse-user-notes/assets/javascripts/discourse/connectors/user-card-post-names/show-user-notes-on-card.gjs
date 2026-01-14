import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import emoji from "discourse/helpers/emoji";
import { i18n } from "discourse-i18n";
import { showUserNotes } from "../../lib/user-notes";

export default class extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return siteSettings.user_notes_enabled && currentUser?.staff;
  }

  @service siteSettings;
  @service store;

  get userNotesCount() {
    return parseInt(
      this.args.user.get("user_notes_count") ||
        this.args.user.get("custom_fields.user_notes_count") ||
        0,
      10
    );
  }

  @action
  showUserNotes() {
    showUserNotes(this.store, this.args.user.id);
  }

  <template>
    <div class="show-user-notes-on-card">
      {{#if this.userNotesCount}}
        <DButton
          @translatedTitle={{i18n "user_notes.show" count=this.userNotesCount}}
          @action={{this.showUserNotes}}
          class="btn-flat"
        >
          {{#if this.siteSettings.enable_emoji}}
            {{emoji "memo"}}
          {{else}}
            {{icon "pen-to-square"}}
          {{/if}}
        </DButton>
      {{/if}}
    </div>
  </template>
}
