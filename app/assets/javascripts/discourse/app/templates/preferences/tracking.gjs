import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import Categories from "discourse/components/user-preferences/categories";
import Tags from "discourse/components/user-preferences/tags";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    {{bodyClass "user-preferences-tracking-page"}}

    <div class="user-preferences__tracking-topics-wrapper">
      <label class="control-label">{{i18n "user.topics_settings"}}</label>

      <div class="user-preferences_tracking-topics-controls">
        <div
          class="controls controls-dropdown"
          data-setting-name="user-new-topic-duration"
        >
          <label>{{i18n "user.new_topic_duration.label"}}</label>
          <ComboBox
            @valueProperty="value"
            @content={{@controller.considerNewTopicOptions}}
            @value={{@controller.model.user_option.new_topic_duration_minutes}}
            @onChange={{fn
              (mut @controller.model.user_option.new_topic_duration_minutes)
            }}
            class="duration"
          />
        </div>

        <div
          class="controls controls-dropdown"
          data-setting-name="user-auto-track-topics"
        >
          <label>{{i18n "user.auto_track_topics"}}</label>
          <ComboBox
            @valueProperty="value"
            @content={{@controller.autoTrackDurations}}
            @value={{@controller.model.user_option.auto_track_topics_after_msecs}}
            @onChange={{fn
              (mut @controller.model.user_option.auto_track_topics_after_msecs)
            }}
          />
        </div>

        <div
          class="controls controls-dropdown"
          data-setting-name="user-notification-level-when-replying"
        >
          <label>{{i18n "user.notification_level_when_replying.label"}}</label>
          <ComboBox
            @valueProperty="value"
            @content={{@controller.notificationLevelsForReplying}}
            @value={{@controller.model.user_option.notification_level_when_replying}}
            @onChange={{fn
              (mut
                @controller.model.user_option.notification_level_when_replying
              )
            }}
          />
        </div>

        <PluginOutlet
          @name="user-preferences-tracking-topics"
          @outletArgs={{lazyHash
            model=@controller.model
            customAttrNames=@controller.customAttrNames
          }}
        />

        <PreferenceCheckbox
          @labelKey="user.topics_unread_when_closed"
          @checked={{@controller.model.user_option.topics_unread_when_closed}}
        />
      </div>
    </div>

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
);
