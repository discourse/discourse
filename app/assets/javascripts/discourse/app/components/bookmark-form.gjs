import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import Form from "discourse/components/form";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import Post from "discourse/models/post";
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

  get title() {
    if (this.args.targetModel instanceof Post) {
      return this.args.targetModel.topic.fancyTitle;
    } else {
      return "";
    }
  }

  <template>
    <Form
      @onRegisterApi={{@registerFormApi}}
      @onSubmit={{@submit}}
      @data={{this.formData}}
      as |form|
    >
      <form.Container @format="full" class="bookmark-excerpt">
        <div class="bookmark-excerpt__icon">
          {{icon "bookmark"}}
        </div>

        <div class="bookmark-excerpt__avatar">
          {{avatar
            @targetModel.user
            imageSize="small"
            class="bookmark-form__excerpt-avatar"
          }}
        </div>

        <div class="bookmark-excerpt__body">
          <div class="bookmark-excerpt__info">
            {{htmlSafe
              (i18n
                "bookmarks.excerpt_title"
                (hash username=@targetModel.user.username title=this.title)
              )
            }}
          </div>
          <div class="bookmark-excerpt__text">
            {{htmlSafe @targetModel.cooked}}
          </div>
        </div>
      </form.Container>

      <form.Field
        @name="name"
        @title={{i18n "post.bookmarks.name_placeholder"}}
        @format="full"
        @validation="length:0,100"
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
