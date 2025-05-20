import { Input } from "@ember/component";
import { array, fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import UserField from "discourse/components/user-field";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import TimezoneInput from "select-kit/components/timezone-input";

export default RouteTemplate(
  <template>
    {{#if @controller.showEnforcedRequiredFieldsNotice}}
      <div class="alert alert-error">{{i18n
          "user.preferences.profile.enforced_required_fields"
        }}</div>
    {{/if}}

    {{#unless @controller.showEnforcedRequiredFieldsNotice}}
      {{#if @controller.siteSettings.allow_users_to_hide_profile}}
        <div
          class="control-group user-hide-profile"
          data-setting-name="user-hide-profile"
        >
          <PreferenceCheckbox
            @labelKey="user.hide_profile"
            @checked={{@controller.model.user_option.hide_profile}}
            data-setting-name="user-hide-profile"
            class="pref-hide-profile"
          />
        </div>
      {{/if}}

      {{#if @controller.canChangeBio}}
        <div class="control-group pref-bio" data-setting-name="user-bio">
          <label class="control-label">{{i18n "user.bio"}}</label>
          <div class="controls bio-composer input-xxlarge">
            <DEditor @value={{@controller.model.bio_raw}} />
          </div>
        </div>
      {{/if}}

      <div
        class="control-group pref-timezone"
        data-setting-name="user-timezone"
      >
        <label class="control-label">{{i18n "user.timezone"}}</label>
        <TimezoneInput
          @value={{@controller.model.user_option.timezone}}
          @onChange={{fn (mut @controller.model.user_option.timezone)}}
          class="input-xxlarge"
        />
        <DButton
          @icon="globe"
          @label="user.use_current_timezone"
          @action={{@controller.useCurrentTimezone}}
          class="btn-default"
        />
      </div>

      {{#if @controller.model.can_change_location}}
        <div
          class="control-group pref-location"
          data-setting-name="user-location"
        >
          <label class="control-label" for="edit-location">{{i18n
              "user.location"
            }}</label>
          <div class="controls">
            <Input
              @type="text"
              @value={{@controller.model.location}}
              class="input-xxlarge"
              id="edit-location"
            />
          </div>
        </div>
      {{/if}}

      {{#if @controller.model.can_change_website}}
        <div
          class="control-group pref-website"
          data-setting-name="user-website"
        >
          <label class="control-label" for="edit-website">{{i18n
              "user.website"
            }}</label>
          <div class="controls">
            <Input
              @type="text"
              @value={{@controller.model.website}}
              class="input-xxlarge"
              id="edit-website"
            />
          </div>
        </div>
      {{/if}}
    {{/unless}}

    {{#each @controller.userFields as |uf|}}
      <div class="control-group" data-setting-name="user-user-fields">
        <UserField @field={{uf.field}} @value={{uf.value}} />
      </div>
    {{/each}}
    <div class="clearfix"></div>

    {{#unless @controller.showEnforcedRequiredFieldsNotice}}
      {{#if @controller.siteSettings.allow_profile_backgrounds}}
        {{#if @controller.canUploadProfileHeader}}
          <div
            class="control-group pref-profile-bg"
            data-setting-name="user-profile-bg"
          >
            <label class="control-label">{{i18n
                "user.change_profile_background.title"
              }}</label>
            <div class="controls">
              <UppyImageUploader
                @imageUrl={{@controller.model.profile_background_upload_url}}
                @onUploadDone={{@controller.profileBackgroundUploadDone}}
                @onUploadDeleted={{fn
                  (mut @controller.model.profile_background_upload_url)
                  null
                }}
                @type="profile_background"
                @id="profile-background-uploader"
              />
            </div>
            <div class="instructions">
              {{i18n "user.change_profile_background.instructions"}}
            </div>
          </div>
        {{/if}}
        {{#if @controller.canUploadUserCardBackground}}
          <div
            class="control-group pref-profile-bg"
            data-setting-name="user-card-bg"
          >
            <label class="control-label">{{i18n
                "user.change_card_background.title"
              }}</label>
            <div class="controls">
              <UppyImageUploader
                @imageUrl={{@controller.model.card_background_upload_url}}
                @onUploadDone={{@controller.cardBackgroundUploadDone}}
                @onUploadDeleted={{fn
                  (mut @controller.model.card_background_upload_url)
                  null
                }}
                @type="card_background"
                @id="profile-card-background-uploader"
              />
            </div>
            <div class="instructions">
              {{i18n "user.change_card_background.instructions"}}
            </div>
          </div>
        {{/if}}
      {{/if}}

      {{#if @controller.siteSettings.allow_featured_topic_on_user_profiles}}
        <div class="control-group" data-setting-name="user-featured-topic">
          <label class="control-label">{{i18n "user.featured_topic"}}</label>
          {{#if @controller.model.featured_topic}}
            <label class="featured-topic-link">
              <LinkTo
                @route="topic"
                @models={{array
                  @controller.model.featured_topic.slug
                  @controller.model.featured_topic.id
                }}
              >
                {{replaceEmoji
                  (htmlSafe @controller.model.featured_topic.fancy_title)
                }}
              </LinkTo>
            </label>
          {{/if}}

          <div>
            <DButton
              @action={{@controller.showFeaturedTopicModal}}
              @label="user.feature_topic_on_profile.open_search"
              class="btn-default feature-topic-on-profile-btn"
            />
            {{#if @controller.model.featured_topic}}
              <DButton
                @action={{@controller.clearFeaturedTopicFromProfile}}
                @label="user.feature_topic_on_profile.clear.title"
                class="btn-danger clear-feature-topic-on-profile-btn"
              />
            {{/if}}
          </div>
          <div class="instructions">
            {{i18n "user.change_featured_topic.instructions"}}
          </div>
        </div>
      {{/if}}

      {{#if @controller.canChangeDefaultCalendar}}
        <div class="control-group" data-setting-name="user-default-calendar">
          <label class="control-label">{{i18n
              "download_calendar.default_calendar"
            }}</label>
          <div>
            <ComboBox
              @valueProperty="value"
              @content={{@controller.calendarOptions}}
              @value={{@controller.model.user_option.default_calendar}}
              @id="user-default-calendar"
              @onChange={{fn
                (mut @controller.model.user_option.default_calendar)
              }}
            />
          </div>
          <div class="instructions">
            {{i18n "download_calendar.default_calendar_instruction"}}
          </div>
        </div>
      {{/if}}

      <PluginOutlet
        @name="user-preferences-profile"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model save=@controller.save}}
      />

      <PluginOutlet
        @name="user-custom-preferences"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />

      <PluginOutlet
        @name="user-custom-controls"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    {{/unless}}

    <SaveControls
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  </template>
);
