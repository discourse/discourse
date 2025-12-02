import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import Categories from "discourse/components/user-preferences/categories";
import Tags from "discourse/components/user-preferences/tags";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class Tracking extends Component {
  get formData() {
    return {
      new_topic_duration_minutes:
        this.args.controller.model.user_option.new_topic_duration_minutes,
      auto_track_topics_after_msecs:
        this.args.controller.model.user_option.auto_track_topics_after_msecs,
      notification_level_when_replying:
        this.args.controller.model.user_option.notification_level_when_replying,
      topics_unread_when_closed:
        this.args.controller.model.user_option.topics_unread_when_closed,
    };
  }

  @action
  saveForm(data) {
    if (data.new_topic_duration_minutes !== undefined) {
      this.args.controller.model.set(
        "user_option.new_topic_duration_minutes",
        data.new_topic_duration_minutes
      );
    }
    if (data.auto_track_topics_after_msecs !== undefined) {
      this.args.controller.model.set(
        "user_option.auto_track_topics_after_msecs",
        data.auto_track_topics_after_msecs
      );
    }
    if (data.notification_level_when_replying !== undefined) {
      this.args.controller.model.set(
        "user_option.notification_level_when_replying",
        data.notification_level_when_replying
      );
    }
    if (data.topics_unread_when_closed !== undefined) {
      this.args.controller.model.set(
        "user_option.topics_unread_when_closed",
        data.topics_unread_when_closed
      );
    }

    const controller = this.args.controller;
    controller.set("saved", false);

    return controller.model
      .save(controller.saveAttrNames)
      .then(() => {
        controller.set("saved", true);
      })
      .catch(popupAjaxError);
  }

  <template>
    {{bodyClass "user-preferences-tracking-page"}}

    <Form
      @data={{this.formData}}
      @onSubmit={{this.saveForm}}
      class="user-preferences__topic-settings-form"
      as |form|
    >
      <form.Section @title={{i18n "user.topics_settings"}}>
        <form.Field
          @name="new_topic_duration_minutes"
          @title={{i18n "user.new_topic_duration.label"}}
          @format="large"
          as |field|
        >
          <field.Select as |select|>
            {{#each @controller.considerNewTopicOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Field
          @name="auto_track_topics_after_msecs"
          @title={{i18n "user.auto_track_topics"}}
          @format="large"
          as |field|
        >
          <field.Select as |select|>
            {{#each @controller.autoTrackDurations as |option|}}
              <select.Option @value={{option.value}}>
                {{option.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Field
          @name="notification_level_when_replying"
          @title={{i18n "user.notification_level_when_replying.label"}}
          @format="large"
          as |field|
        >
          <field.Select as |select|>
            {{#each @controller.notificationLevelsForReplying as |option|}}
              <select.Option @value={{option.value}}>
                {{option.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <PluginOutlet
          @name="user-preferences-tracking-topics"
          @outletArgs={{lazyHash
            model=@controller.model
            customAttrNames=@controller.customAttrNames
            form=form
          }}
        />

        <form.Field
          @name="topics_unread_when_closed"
          @title={{i18n "user.topics_unread_when_closed"}}
          @format="large"
          as |field|
        >
          <field.Checkbox />
        </form.Field>
      </form.Section>
      <form.Submit />
    </Form>

    <div class="user-preferences__tracking-categories-tags-wrapper">
      <div>
        <Categories
          @canSee={{@controller.canSee}}
          @model={{@controller.model}}
          @selectedCategories={{@controller.selectedCategories}}
          @hideMutedTags={{@controller.hideMutedTags}}
          @siteSettings={{@controller.siteSettings}}
        />
      </div>

      <div>
        <Tags
          @model={{@controller.model}}
          @selectedTags={{@controller.selectedTags}}
          @save={{@controller.save}}
          @siteSettings={{@controller.siteSettings}}
        />
      </div>
    </div>
    {{#if @controller.showMutePrecedenceSetting}}
      <div
        class="control-group user-preferences__watched-precedence-over-muted"
      >
        <PreferenceCheckbox
          data-setting-name="watched-precedence-over-muted"
          @labelKey="user.watched_precedence_over_muted"
          @checked={{@controller.model.user_option.watched_precedence_over_muted}}
        />
      </div>
    {{/if}}

    {{#if @controller.canSave}}
      <SaveControls
        @model={{@controller.model}}
        @action={{@controller.save}}
        @saved={{@controller.saved}}
      />
    {{/if}}
  </template>
}
