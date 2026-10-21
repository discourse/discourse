import { fn } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import Categories from "discourse/components/user-preferences/categories";
import Tags from "discourse/components/user-preferences/tags";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import ComboBox from "discourse/select-kit/components/combo-box";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
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
          class="duration"
          @content={{@controller.considerNewTopicOptions}}
          @onChange={{fn
            (mut @controller.model.user_option.new_topic_duration_minutes)
          }}
          @value={{@controller.model.user_option.new_topic_duration_minutes}}
          @valueProperty="value"
        />
      </div>

      <div
        class="controls controls-dropdown"
        data-setting-name="user-auto-track-topics"
      >
        <label>{{i18n "user.auto_track_topics"}}</label>
        <ComboBox
          @content={{@controller.autoTrackDurations}}
          @onChange={{fn
            (mut @controller.model.user_option.auto_track_topics_after_msecs)
          }}
          @value={{@controller.model.user_option.auto_track_topics_after_msecs}}
          @valueProperty="value"
        />
      </div>

      <div
        class="controls controls-dropdown"
        data-setting-name="user-notification-level-when-replying"
      >
        <label>{{i18n "user.notification_level_when_replying.label"}}</label>
        <ComboBox
          @content={{@controller.notificationLevelsForReplying}}
          @onChange={{fn
            (mut @controller.model.user_option.notification_level_when_replying)
          }}
          @value={{@controller.model.user_option.notification_level_when_replying}}
          @valueProperty="value"
        />
      </div>

      <PluginOutlet
        @name="user-preferences-tracking-topics"
        @outletArgs={{lazyHash
          model=@controller.model
          customAttrNames=@controller.customAttrNames
        }}
      />
    </div>
  </div>

  <div class="user-preferences__tracking-categories-tags-wrapper">
    <div>
      <Categories
        @canSee={{@controller.canSee}}
        @hideMutedTags={{@controller.hideMutedTags}}
        @model={{@controller.model}}
        @selectedCategories={{@controller.selectedCategories}}
        @siteSettings={{@controller.siteSettings}}
      />
    </div>

    <div>
      <Tags
        @model={{@controller.model}}
        @save={{@controller.save}}
        @selectedTags={{@controller.selectedTags}}
        @siteSettings={{@controller.siteSettings}}
      />
    </div>
  </div>
  {{#if @controller.showMutePrecedenceSetting}}
    <div class="control-group user-preferences__watched-precedence-over-muted">
      <PreferenceCheckbox
        data-setting-name="watched-precedence-over-muted"
        @checked={{@controller.model.user_option.watched_precedence_over_muted}}
        @labelKey="user.watched_precedence_over_muted"
      />
    </div>
  {{/if}}

  {{#if @controller.canSave}}
    <DSaveControls
      @action={{@controller.save}}
      @model={{@controller.model}}
      @saved={{@controller.saved}}
    />
  {{/if}}
</template>
