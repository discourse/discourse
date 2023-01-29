import Controller from "@ember/controller";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { cookAsync } from "discourse/lib/text";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { readOnly } from "@ember/object/computed";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";

export default Controller.extend({
  dialog: service(),
  subpageTitle: I18n.t("user.preferences_nav.profile"),
  init() {
    this._super(...arguments);
    this.saveAttrNames = [
      "bio_raw",
      "website",
      "location",
      "custom_fields",
      "user_fields",
      "profile_background_upload_url",
      "card_background_upload_url",
      "date_of_birth",
      "timezone",
      "default_calendar",
    ];

    this.calendarOptions = [
      { name: I18n.t("download_calendar.google"), value: "google" },
      { name: I18n.t("download_calendar.ics"), value: "ics" },
    ];
  },

  @discourseComputed("model.user_fields.@each.value")
  userFields() {
    let siteUserFields = this.site.user_fields;
    if (isEmpty(siteUserFields)) {
      return;
    }

    // Staff can edit fields that are not `editable`
    if (!this.currentUser.staff) {
      siteUserFields = siteUserFields.filterBy("editable", true);
    }

    return siteUserFields.sortBy("position").map((field) => {
      const value = this.model.user_fields?.[field.id.toString()];
      return EmberObject.create({ field, value });
    });
  },

  @discourseComputed("model.user_option.default_calendar")
  canChangeDefaultCalendar(defaultCalendar) {
    return defaultCalendar !== "none_selected";
  },

  canChangeBio: readOnly("model.can_change_bio"),

  canChangeLocation: readOnly("model.can_change_location"),

  canChangeWebsite: readOnly("model.can_change_website"),

  canUploadProfileHeader: readOnly("model.can_upload_profile_header"),

  canUploadUserCardBackground: readOnly(
    "model.can_upload_user_card_background"
  ),

  actions: {
    showFeaturedTopicModal() {
      const modal = showModal("feature-topic-on-profile", {
        model: this.model,
        title: "user.feature_topic_on_profile.title",
      });
      modal.set("onClose", () => {
        document.querySelector(".feature-topic-on-profile-btn")?.focus();
      });
    },

    clearFeaturedTopicFromProfile() {
      this.dialog.yesNoConfirm({
        message: I18n.t("user.feature_topic_on_profile.clear.warning"),
        didConfirm: () => {
          return ajax(`/u/${this.model.username}/clear-featured-topic`, {
            type: "PUT",
          })
            .then(() => {
              this.model.set("featured_topic", null);
            })
            .catch(popupAjaxError);
        },
      });
    },

    useCurrentTimezone() {
      this.model.set("user_option.timezone", moment.tz.guess());
    },

    _updateUserFields() {
      const model = this.model,
        userFields = this.userFields;

      if (!isEmpty(userFields)) {
        const modelFields = model.get("user_fields");
        if (!isEmpty(modelFields)) {
          userFields.forEach(function (uf) {
            const value = uf.get("value");
            modelFields[uf.get("field.id").toString()] = isEmpty(value)
              ? null
              : value;
          });
        }
      }
    },

    save() {
      this.set("saved", false);
      const model = this.model;

      // Update the user fields
      this.send("_updateUserFields");

      return model
        .save(this.saveAttrNames)
        .then(() => {
          cookAsync(model.get("bio_raw"))
            .then(() => {
              model.set("bio_cooked");
              this.set("saved", true);
            })
            .catch(popupAjaxError);
        })
        .catch(popupAjaxError);
    },
  },
});
