import Component from "@ember/component";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { emojiUrlFor } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import { showUserNotes } from "../../lib/user-notes";

@tagName("div")
@classNames("after-reviewable-post-user-outlet", "show-user-notes-on-flags")
export default class ShowUserNotesOnFlags extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.user_notes_enabled && args.user;
  }

  @service store;

  init() {
    super.init(...arguments);
    const model = EmberObject.create(this.user);
    const userNotesCount = model.get("custom_fields.user_notes_count") || 0;
    this.setProperties({
      userNotesCount,
      emojiEnabled: this.siteSettings.enable_emoji,
      emojiUrl: emojiUrlFor("memo"),
      userNotesTitle: i18n("user_notes.show", {
        count: userNotesCount,
      }),
    });
  }

  @action
  showUserNotes() {
    const user = this.user;
    showUserNotes(this.store, user.id, (count) =>
      this.set("userNotesCount", count)
    );
  }

  <template>
    {{#if this.userNotesCount}}
      <DButton
        @translatedTitle={{this.userNotesTitle}}
        @action={{this.showUserNotes}}
        class="btn btn-flat"
      >
        {{#if this.emojiEnabled}}
          <img
            src={{this.emojiUrl}}
            title={{this.userNotesTitle}}
            alt
            class="emoji"
          />
        {{else}}
          {{icon "pen-to-square"}}
        {{/if}}
      </DButton>
    {{/if}}
  </template>
}
