import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import Form from "discourse/components/form";
import avatar from "discourse/helpers/avatar";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

export default class BookmarkForm extends Component {
  get reminderValidation() {
    return `dateAfterOrEqual:${moment().format("YYYY-MM-DD HH:mm")}`;
  }

  @cached
  get formData() {
    return {
      id: this.args.bookmark.id,
      name: this.args.bookmark.name,
      reminderAt: moment(this.args.bookmark.reminderAt).toDate(),
      autoDeletePreference:
        this.args.bookmark.autoDeletePreference ??
        AUTO_DELETE_PREFERENCES.CLEAR_REMINDER,
      persistChoice: null,
      bookmarkableId: this.args.bookmark.bookmarkableId,
      bookmarkableType: this.args.bookmark.bookmarkableType,
    };
  }

  <template>
    <Form
      @onRegisterApi={{@registerFormApi}}
      @onSubmit={{@submit}}
      @data={{this.formData}}
      as |form|
    >
      <form.Container @format="full" class="bookmark-form__excerpt">
        <div class="bookmark-form__excerpt-header">
          {{avatar
            @targetModel.user
            imageSize="small"
            class="bookmark-form__excerpt-avatar"
          }}
          <span class="bookmark-form__excerpt-title">
            {{@targetModel.user.username}}
          </span>
        </div>
        <div class="bookmark-form__excerpt__body">
          {{htmlSafe @targetModel.cooked}}
        </div>
      </form.Container>

      <form.Field
        @name="name"
        @title={{i18n "post.bookmarks.name_placeholder"}}
        @format="full"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="reminderAt"
        @title={{i18n "post.bookmarks.set_reminder"}}
        @validation={{this.reminderValidation}}
        @format="full"
        as |field|
      >
        <field.Calendar />
      </form.Field>

      <form.Field
        @name="autoDeletePreference"
        @title={{i18n "bookmarks.auto_delete_preference.label"}}
        @validation="required"
        @format="full"
        as |field|
      >
        <field.RadioGroup as |radioGroup|>
          <radioGroup.Radio @value={{AUTO_DELETE_PREFERENCES.CLEAR_REMINDER}}>
            {{i18n "bookmarks.auto_delete_preference.clear_reminder"}}
          </radioGroup.Radio>
          <radioGroup.Radio @value={{AUTO_DELETE_PREFERENCES.NEVER}}>
            {{i18n "bookmarks.auto_delete_preference.never"}}
          </radioGroup.Radio>
          <radioGroup.Radio
            @value={{AUTO_DELETE_PREFERENCES.WHEN_REMINDER_SENT}}
          >
            {{i18n "bookmarks.auto_delete_preference.when_reminder_sent"}}
          </radioGroup.Radio>
          <radioGroup.Radio @value={{AUTO_DELETE_PREFERENCES.ON_OWNER_REPLY}}>
            {{i18n "bookmarks.auto_delete_preference.on_owner_reply"}}
          </radioGroup.Radio>
        </field.RadioGroup>
      </form.Field>

      <form.Field
        @name="persistChoice"
        @title={{i18n "bookmarks.persist_auto_delete_preference_choice"}}
        @showTitle={{false}}
        @format="full"
        as |field|
      >
        <field.Checkbox />
      </form.Field>
    </Form>
  </template>
}
