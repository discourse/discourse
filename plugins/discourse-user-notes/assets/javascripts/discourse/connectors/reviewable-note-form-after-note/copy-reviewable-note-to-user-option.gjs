import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class CopyReviewableNoteToUserOption extends Component {
  static shouldRender(args, context) {
    return (
      context.siteSettings.user_notes_enabled && context.currentUser?.staff
    );
  }

  <template>
    <@form.CheckboxGroup as |group|>
      <group.Field
        @name="copy_note_to_user"
        @title={{i18n "user_notes.copy_reviewable_note"}}
        @format="full"
        as |field|
      >
        <field.Checkbox />
      </group.Field>
    </@form.CheckboxGroup>
  </template>
}
