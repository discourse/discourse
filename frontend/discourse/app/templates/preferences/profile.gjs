import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action, get } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import Form from "discourse/components/form";
import FeatureTopicOnProfileModal from "discourse/components/modal/feature-topic-on-profile";
import PluginOutlet from "discourse/components/plugin-outlet";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import UserField from "discourse/components/user-field";
import lazyHash from "discourse/helpers/lazy-hash";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import { i18n } from "discourse-i18n";

const validationFor = (field) => {
  if (!get(field, "required")) {
    return null;
  }
  return get(field, "field_type") === "confirm" ? "accepted" : "required";
};

class MutableField extends Component {
  get value() {
    return this.args.value;
  }

  set value(val) {
    this.args.set(val);
  }

  <template>{{yield this}}</template>
}

export default class Profile extends Component {
  @service dialog;
  @service modal;

  constructor() {
    super(...arguments);
  }

  @action
  updateTimezone(field, timezone) {
    field.set(timezone);
  }

  @action
  useCurrentTimezone(field) {
    field.set(moment.tz.guess(true));
  }

  @action
  profileBackgroundUploadDone(field, upload) {
    field.set(upload.url);
  }

  @action
  cardBackgroundUploadDone(field, upload) {
    field.set(upload.url);
  }

  @action
  setFeaturedTopic(field, v) {
    field.set(v);
  }

  @action
  async showFeaturedTopicModal(field) {
    await this.modal.show(FeatureTopicOnProfileModal, {
      model: {
        user: this.args.controller.model,
        setFeaturedTopic: (v) => this.setFeaturedTopic(field, v),
      },
    });
    document.querySelector(".feature-topic-on-profile-btn")?.focus();
  }

  @action
  clearFeaturedTopicFromProfile(field) {
    this.dialog.yesNoConfirm({
      message: i18n("user.feature_topic_on_profile.clear.warning"),
      didConfirm: () => {
        return ajax(
          `/u/${this.args.controller.model.username}/clear-featured-topic`,
          {
            type: "PUT",
          }
        )
          .then(() => {
            field.set(null);
          })
          .catch(popupAjaxError);
      },
    });
  }

  get formData() {
    const data = {
      hide_profile: this.args.controller.model.user_option.hide_profile,
      bio_raw: this.args.controller.model.bio_raw,
      timezone: this.args.controller.model.user_option.timezone,
      location: this.args.controller.model.location,
      website: this.args.controller.model.website,
      profile_background_upload_url:
        this.args.controller.model.profile_background_upload_url,
      card_background_upload_url:
        this.args.controller.model.card_background_upload_url,
      featured_topic: this.args.controller.model.featured_topic,
      default_calendar: this.args.controller.model.user_option.default_calendar,
    };

    this.args.controller.userFields?.forEach((uf) => {
      data[`user_field_${uf.field.id}`] = uf.value;
    });

    return data;
  }

  @action
  saveForm(data) {
    // ... existing mapped fields ...
    if (data.hide_profile !== undefined) {
      this.args.controller.model.set(
        "user_option.hide_profile",
        data.hide_profile
      );
    }
    if (data.bio_raw !== undefined) {
      this.args.controller.model.set("bio_raw", data.bio_raw);
    }
    if (data.timezone !== undefined) {
      this.args.controller.model.set("user_option.timezone", data.timezone);
    }
    if (data.location !== undefined) {
      this.args.controller.model.set("location", data.location);
    }
    if (data.website !== undefined) {
      this.args.controller.model.set("website", data.website);
    }
    if (data.profile_background_upload_url !== undefined) {
      this.args.controller.model.set(
        "profile_background_upload_url",
        data.profile_background_upload_url
      );
    }
    if (data.card_background_upload_url !== undefined) {
      this.args.controller.model.set(
        "card_background_upload_url",
        data.card_background_upload_url
      );
    }
    if (data.featured_topic !== undefined) {
      this.args.controller.model.set("featured_topic", data.featured_topic);
    }
    if (data.default_calendar !== undefined) {
      this.args.controller.model.set(
        "user_option.default_calendar",
        data.default_calendar
      );
    }

    // Update User Fields
    const modelFields = this.args.controller.model.get("user_fields");
    if (modelFields) {
      this.args.controller.userFields?.forEach((uf) => {
        const key = `user_field_${uf.field.id}`;
        if (data[key] !== undefined) {
          modelFields[uf.field.id.toString()] = data[key];
        }
      });
    }

    const controller = this.args.controller;
    controller.set("saved", false);

    return controller.model
      .save(controller.saveAttrNames)
      .then(({ user }) => {
        controller.model.set("bio_cooked", user.bio_cooked);
        if (controller.currentUser) {
          controller.currentUser.set("needs_required_fields_check", false);
        }
        controller.set("saved", true);
      })
      .catch(popupAjaxError);
  }

  <template>
    <Form @data={{this.formData}} @onSubmit={{this.saveForm}} as |form|>

      {{#if @controller.canChangeBio}}
        <form.Field
          @name="bio_raw"
          @title={{i18n "user.bio"}}
          @format="full"
          as |field|
        >
          <field.Custom>
            <MutableField
              @value={{field.value}}
              @set={{field.set}}
              as |wrapper|
            >
              <DEditor
                @value={{wrapper.value}}
                @forceEditorMode={{USER_OPTION_COMPOSITION_MODES.rich}}
                @hidePreview={{true}}
              />
            </MutableField>
          </field.Custom>
        </form.Field>
      {{/if}}

      {{#if @controller.siteSettings.allow_users_to_hide_profile}}
        <form.Field
          @format="large"
          @name="hide_profile"
          @title={{i18n "user.hide_profile"}}
          as |field|
        >
          <field.Checkbox />
        </form.Field>
      {{/if}}

      {{#if @controller.userFields.length}}
        <form.Section @title="Custom Fields">
          {{#each @controller.userFields as |uf|}}
            <form.Field
              @format="large"
              @name={{concat "user_field_" uf.field.id}}
              @title={{uf.field.name}}
              @description={{uf.field.description}}
              @validation={{validationFor uf.field}}
              as |field|
            >
              <field.Custom>
                <MutableField
                  @value={{field.value}}
                  @set={{field.set}}
                  as |wrapper|
                >
                  <UserField
                    @field={{uf.field}}
                    @value={{wrapper.value}}
                    @validation={{field.validation}}
                    @showLabel={{false}}
                    @showDescription={{false}}
                  />
                </MutableField>
              </field.Custom>
            </form.Field>
          {{/each}}
        </form.Section>
      {{/if}}

      <form.Section @title="Location and Website">
        <form.Field
          @format="large"
          @name="timezone"
          @title={{i18n "user.timezone"}}
          as |field|
        >
          <field.Custom>
            <TimezoneInput
              @value={{field.value}}
              @onChange={{fn this.updateTimezone field}}
            />
            <DButton
              @icon="globe"
              @label="user.use_current_timezone"
              @action={{fn this.useCurrentTimezone field}}
              class="btn-default"
            />
          </field.Custom>
        </form.Field>

        {{#if @controller.model.can_change_location}}
          <form.Field
            @format="large"
            @name="location"
            @title={{i18n "user.location"}}
            as |field|
          >
            <field.Input />
          </form.Field>
        {{/if}}

        {{#if @controller.model.can_change_website}}
          <form.Field
            @format="large"
            @name="website"
            @title={{i18n "user.website"}}
            as |field|
          >
            <field.Input />
          </form.Field>
        {{/if}}
      </form.Section>

      <form.Section @title="User Card Images">
        {{#if @controller.siteSettings.allow_profile_backgrounds}}
          {{#if @controller.canUploadProfileHeader}}
            <form.Field
              @format="large"
              @name="profile_background_upload_url"
              @title={{i18n "user.change_profile_background.title"}}
              @description={{i18n
                "user.change_profile_background.instructions"
              }}
              as |field|
            >
              <field.Custom>
                <UppyImageUploader
                  @imageUrl={{field.value}}
                  @onUploadDone={{fn this.profileBackgroundUploadDone field}}
                  @onUploadDeleted={{fn field.set null}}
                  @type="profile_background"
                  @id="profile-background-uploader-sandbox"
                />
              </field.Custom>
            </form.Field>
          {{/if}}

          {{#if @controller.canUploadUserCardBackground}}
            <form.Field
              @format="large"
              @name="card_background_upload_url"
              @title={{i18n "user.change_card_background.title"}}
              @description={{i18n "user.change_card_background.instructions"}}
              as |field|
            >
              <field.Custom>
                <UppyImageUploader
                  @imageUrl={{field.value}}
                  @onUploadDone={{fn this.cardBackgroundUploadDone field}}
                  @onUploadDeleted={{fn field.set null}}
                  @type="card_background"
                  @id="profile-card-background-uploader-sandbox"
                />
              </field.Custom>
            </form.Field>
          {{/if}}
        {{/if}}
      </form.Section>

      {{#if @controller.siteSettings.allow_featured_topic_on_user_profiles}}
        <form.Field
          @format="large"
          @name="featured_topic"
          @title={{i18n "user.featured_topic"}}
          @description={{i18n "user.change_featured_topic.instructions"}}
          as |field|
        >
          <field.Custom>
            {{#if field.value}}
              <label class="featured-topic-link">
                <LinkTo
                  @route="topic"
                  @models={{array field.value.slug field.value.id}}
                >
                  {{replaceEmoji (htmlSafe field.value.fancy_title)}}
                </LinkTo>
              </label>
            {{/if}}

            <div>
              <DButton
                @action={{fn this.showFeaturedTopicModal field}}
                @label="user.feature_topic_on_profile.open_search"
                class="btn-default feature-topic-on-profile-btn"
              />
              {{#if field.value}}
                <DButton
                  @action={{fn this.clearFeaturedTopicFromProfile field}}
                  @label="user.feature_topic_on_profile.clear.title"
                  class="btn-danger clear-feature-topic-on-profile-btn"
                />
              {{/if}}
            </div>
          </field.Custom>
        </form.Field>
      {{/if}}

      {{#if @controller.canChangeDefaultCalendar}}
        <form.Field
          @format="large"
          @name="default_calendar"
          @title={{i18n "download_calendar.default_calendar"}}
          @description={{i18n "download_calendar.default_calendar_instruction"}}
          as |field|
        >
          <field.Select
            @content={{@controller.calendarOptions}}
            @optionValuePath="value"
            @optionLabelPath="name"
          />
        </form.Field>
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

      <form.Submit />
    </Form>
  </template>
}
