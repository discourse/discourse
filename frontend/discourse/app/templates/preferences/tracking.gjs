import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import Categories from "discourse/components/user-preferences/categories";
import Tags from "discourse/components/user-preferences/tags";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class Tracking extends Component {
  get formData() {
    const data = {
      new_topic_duration_minutes:
        this.args.controller.model.user_option.new_topic_duration_minutes,
      auto_track_topics_after_msecs:
        this.args.controller.model.user_option.auto_track_topics_after_msecs,
      notification_level_when_replying:
        this.args.controller.model.user_option.notification_level_when_replying,
      topics_unread_when_closed:
        this.args.controller.model.user_option.topics_unread_when_closed,
      watched_precedence_over_muted:
        this.args.controller.model.user_option.watched_precedence_over_muted,
      watched_category_ids: this.args.controller.model.watchedCategories || [],
      tracked_category_ids: this.args.controller.model.trackedCategories || [],
      watched_first_post_category_ids:
        this.args.controller.model.watchedFirstPostCategories || [],
    };

    if (this.args.controller.siteSettings.mute_all_categories_by_default) {
      data.regular_category_ids =
        this.args.controller.model.regularCategories || [];
    } else {
      data.muted_category_ids =
        this.args.controller.model.mutedCategories || [];
    }

    if (this.args.controller.siteSettings.tagging_enabled) {
      data.watched_tags = this.args.controller.model.watched_tags || [];
      data.tracked_tags = this.args.controller.model.tracked_tags || [];
      data.watching_first_post_tags =
        this.args.controller.model.watching_first_post_tags || [];
      data.muted_tags = this.args.controller.model.muted_tags || [];
    }

    return data;
  }

  @action
  saveForm(data) {
    // Topic settings
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
    if (data.watched_precedence_over_muted !== undefined) {
      this.args.controller.model.set(
        "user_option.watched_precedence_over_muted",
        data.watched_precedence_over_muted
      );
    }

    // Category settings
    if (data.watched_category_ids !== undefined) {
      this.args.controller.model.set(
        "watchedCategories",
        data.watched_category_ids
      );
    }
    if (data.tracked_category_ids !== undefined) {
      this.args.controller.model.set(
        "trackedCategories",
        data.tracked_category_ids
      );
    }
    if (data.watched_first_post_category_ids !== undefined) {
      this.args.controller.model.set(
        "watchedFirstPostCategories",
        data.watched_first_post_category_ids
      );
    }
    if (this.args.controller.siteSettings.mute_all_categories_by_default) {
      if (data.regular_category_ids !== undefined) {
        this.args.controller.model.set(
          "regularCategories",
          data.regular_category_ids
        );
      }
    } else {
      if (data.muted_category_ids !== undefined) {
        this.args.controller.model.set(
          "mutedCategories",
          data.muted_category_ids
        );
      }
    }

    // Tag settings
    if (this.args.controller.siteSettings.tagging_enabled) {
      if (data.watched_tags !== undefined) {
        this.args.controller.model.set("watched_tags", data.watched_tags);
      }
      if (data.tracked_tags !== undefined) {
        this.args.controller.model.set("tracked_tags", data.tracked_tags);
      }
      if (data.watching_first_post_tags !== undefined) {
        this.args.controller.model.set(
          "watching_first_post_tags",
          data.watching_first_post_tags
        );
      }
      if (data.muted_tags !== undefined) {
        this.args.controller.model.set("muted_tags", data.muted_tags);
      }
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
      class="user-preferences__tracking-form"
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
        {{#if @controller.showMutePrecedenceSetting}}
          <form.Field
            @name="watched_precedence_over_muted"
            @title={{i18n "user.watched_precedence_over_muted"}}
            @format="large"
            as |field|
          >
            <field.Checkbox />
          </form.Field>
        {{/if}}
      </form.Section>

      <form.Section @title={{i18n "user.categories_settings"}}>
        <Categories
          @canSee={{@controller.canSee}}
          @model={{@controller.model}}
          @selectedCategories={{@controller.selectedCategories}}
          @hideMutedTags={{@controller.hideMutedTags}}
          @siteSettings={{@controller.siteSettings}}
          @form={{form}}
        />
      </form.Section>

      {{#if @controller.siteSettings.tagging_enabled}}
        <form.Section @title={{i18n "user.tag_settings"}}>
          <Tags
            @model={{@controller.model}}
            @selectedTags={{@controller.selectedTags}}
            @siteSettings={{@controller.siteSettings}}
            @form={{form}}
          />
        </form.Section>
      {{/if}}

      <form.Submit />
    </Form>
  </template>
}
