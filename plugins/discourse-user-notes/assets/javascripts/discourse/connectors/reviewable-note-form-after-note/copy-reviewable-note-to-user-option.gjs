import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class CopyReviewableNoteToUserOption extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return siteSettings.user_notes_enabled && currentUser?.staff;
  }

  get username() {
    return (
      this.args.outletArgs?.reviewable?.target_created_by?.username || "user"
    );
  }

  <template>
    <@form.CheckboxGroup as |group|>
      <group.Field
        @name="copy_note_to_user"
        @title={{i18n "user_notes.copy_reviewable_note" username=this.username}}
        @format="full"
        as |field|
      >
        <field.Checkbox />
      </group.Field>
    </@form.CheckboxGroup>
  </template>
}
