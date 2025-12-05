import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import Categories from "discourse/components/user-preferences/categories";
import Tags from "discourse/components/user-preferences/tags";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class Tracking extends Component {
  @tracked topicTrackingFormApi = null;

  get topicTrackingData() {
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
    };

    // Include plugin-added fields from customAttrNames
    // Access customAttrNames directly (not via .get()) to ensure reactivity
    this.args.controller.customAttrNames?.forEach((fieldName) => {
      // Check if field exists on user_option
      if (this.args.controller.model.user_option[fieldName] !== undefined) {
        data[fieldName] = this.args.controller.model.get(
          `user_option.${fieldName}`
        );
      }
      // check if field exists directly on model
      else if (this.args.controller.model[fieldName] !== undefined) {
        data[fieldName] = this.args.controller.model.get(fieldName);
      }
    });

    return data;
  }

  @action
  updateFormDataWithCustomFields() {
    if (!this.topicTrackingFormApi) {
      return;
    }

    // Add any custom fields to the form data
    // This ensures fields are tracked even if they're registered after form initialization
    this.args.controller.customAttrNames?.forEach((fieldName) => {
      const currentFormValue = this.topicTrackingFormApi.get(fieldName);

      // Get the value from the model (check user_option first, then model directly)
      let modelValue;
      if (this.args.controller.model.user_option[fieldName] !== undefined) {
        modelValue = this.args.controller.model.get(`user_option.${fieldName}`);
      } else if (this.args.controller.model[fieldName] !== undefined) {
        modelValue = this.args.controller.model.get(fieldName);
      }

      // Set the value in the form if:
      // 1. The field doesn't exist in form data yet (currentFormValue is undefined), OR
      // 2. The model value is different from the form value
      // This ensures the field is always registered and synced with the model
      if (currentFormValue === undefined || currentFormValue !== modelValue) {
        this.topicTrackingFormApi.set(fieldName, modelValue);
      }
    });
  }

  @action
  registerTopicTrackingFormApi(api) {
    this.topicTrackingFormApi = api;
    // Update form data immediately if custom fields are already registered
    // The did-update modifier will handle updates when customAttrNames changes
    this.updateFormDataWithCustomFields();
  }

  get customAttrNamesKey() {
    // Create a reactive key based on the array contents for did-update to watch
    return this.args.controller.customAttrNames?.join(",") || "";
  }

  get categoryTrackingData() {
    return {
      watched_category_ids: this.args.controller.model.watchedCategories || [],
      tracked_category_ids: this.args.controller.model.trackedCategories || [],
      watched_first_post_category_ids:
        this.args.controller.model.watchedFirstPostCategories || [],
      ...(this.args.controller.siteSettings.mute_all_categories_by_default
        ? {
            regular_category_ids:
              this.args.controller.model.regularCategories || [],
          }
        : {
            muted_category_ids:
              this.args.controller.model.mutedCategories || [],
          }),
    };
  }

  get tagTrackingData() {
    return {
      watched_tags: this.args.controller.model.watched_tags || [],
      tracked_tags: this.args.controller.model.tracked_tags || [],
      watching_first_post_tags:
        this.args.controller.model.watching_first_post_tags || [],
      muted_tags: this.args.controller.model.muted_tags || [],
    };
  }

  @action
  saveTopicTrackingData(data) {
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

    // Handle plugin-added fields from customAttrNames
    this.args.controller.customAttrNames?.forEach((fieldName) => {
      if (data[fieldName] !== undefined) {
        // Most custom fields are stored on user_option
        const userOptionValue = this.args.controller.model.get(
          `user_option.${fieldName}`
        );
        if (userOptionValue !== undefined) {
          this.args.controller.model.set(
            `user_option.${fieldName}`,
            data[fieldName]
          );
        } else {
          this.args.controller.model.set(fieldName, data[fieldName]);
        }
      }
    });

    const controller = this.args.controller;
    controller.trackedTopicsSaved = false;

    return controller.model
      .save(controller.saveAttrNames)
      .then(() => {
        controller.trackedTopicsSaved = true;
      })
      .catch(popupAjaxError);
  }

  @action
  saveCategoryTrackingData(data) {
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

    const controller = this.args.controller;
    controller.trackedCategoriesSaved = false;

    return controller.model
      .save(controller.saveAttrNames)
      .then(() => {
        controller.trackedCategoriesSaved = true;
      })
      .catch(popupAjaxError);
  }

  @action
  saveTagTrackingData(data) {
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

    const controller = this.args.controller;
    controller.trackedTagsSaved = false;

    return controller.model
      .save(controller.saveAttrNames)
      .then(() => {
        controller.trackedTagsSaved = true;
      })
      .catch(popupAjaxError);
  }

  <template>
    {{bodyClass "user-preferences-tracking-page"}}

    <Form
      @data={{this.topicTrackingData}}
      @onSubmit={{this.saveTopicTrackingData}}
      @onRegisterApi={{this.registerTopicTrackingFormApi}}
      class="user-preferences__tracking-form topic-tracking"
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

        <div
          {{didInsert this.updateFormDataWithCustomFields}}
          {{didUpdate
            this.updateFormDataWithCustomFields
            this.customAttrNamesKey
          }}
        >
          <PluginOutlet
            @name="user-preferences-tracking-topics"
            @outletArgs={{lazyHash
              model=@controller.model
              customAttrNames=@controller.customAttrNames
              form=form
            }}
          />
        </div>

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
      <div class="controls save-button">
        <form.Submit class="save-changes" />
        {{#if @controller.trackedTopicsSaved}}
          <span class="saved">{{i18n "saved"}}</span>
        {{/if}}
      </div>
    </Form>

    <Form
      @data={{this.categoryTrackingData}}
      @onSubmit={{this.saveCategoryTrackingData}}
      class="user-preferences__tracking-form"
      as |form|
    >
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
      <div class="controls save-button">
        <form.Submit class="save-changes" />
        {{#if @controller.trackedCategoriesSaved}}
          <span class="saved">{{i18n "saved"}}</span>
        {{/if}}
      </div>
    </Form>

    {{#if @controller.siteSettings.tagging_enabled}}
      <Form
        @data={{this.tagTrackingData}}
        @onSubmit={{this.saveTagTrackingData}}
        class="user-preferences__tracking-form"
        as |form|
      >
        <form.Section @title={{i18n "user.tag_settings"}}>
          <Tags
            @model={{@controller.model}}
            @selectedTags={{@controller.selectedTags}}
            @siteSettings={{@controller.siteSettings}}
            @form={{form}}
          />
        </form.Section>
        <div class="controls save-button">
          <form.Submit class="save-changes" />
          {{#if @controller.trackedTagsSaved}}
            <span class="saved">{{i18n "saved"}}</span>
          {{/if}}
        </div>
      </Form>
    {{/if}}
  </template>
}
