import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { compare, isEmpty } from "@ember/utils";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ProfileController extends Controller {
  subpageTitle = i18n("user.preferences_nav.profile");

  @readOnly("model.can_change_bio") canChangeBio;
  @readOnly("model.can_change_location") canChangeLocation;
  @readOnly("model.can_change_website") canChangeWebsite;
  @readOnly("model.can_upload_profile_header") canUploadProfileHeader;
  @readOnly("model.can_upload_user_card_background")
  canUploadUserCardBackground;

  saveAttrNames = [
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
    "hide_profile",
  ];

  calendarOptions = [
    { name: i18n("download_calendar.google"), value: "google" },
    { name: i18n("download_calendar.ics"), value: "ics" },
  ];

  @discourseComputed("model.user_fields.@each.value")
  userFields() {
    let siteUserFields = this.site.user_fields;
    if (isEmpty(siteUserFields)) {
      return;
    }

    if (this.showEnforcedRequiredFieldsNotice) {
      return this._missingRequiredFields(
        this.site.user_fields,
        this.model.user_fields
      );
    }

    // Staff can edit fields that are not `editable`
    if (!this.currentUser.staff) {
      siteUserFields = siteUserFields.filter((field) => field.editable);
    }

    return siteUserFields
      .sort((a, b) => compare(a?.position, b?.position))
      .map((field) => {
        const value = this.model.user_fields?.[field.id.toString()];
        return EmberObject.create({ field, value });
      });
  }

  @discourseComputed("currentUser.needs_required_fields_check")
  showEnforcedRequiredFieldsNotice(needsRequiredFieldsCheck) {
    return needsRequiredFieldsCheck;
  }

  @discourseComputed("model.user_option.default_calendar")
  canChangeDefaultCalendar(defaultCalendar) {
    return defaultCalendar !== "none_selected";
  }

  _missingRequiredFields(siteFields, userFields) {
    return siteFields
      .filter(
        (siteField) =>
          siteField.requirement === "for_all_users" && !userFields[siteField.id]
      )
      .map((field) => EmberObject.create({ field, value: "" }));
  }

  @action
  useCurrentTimezone() {
    this.model.set("user_option.timezone", moment.tz.guess(true));
  }

  @action
  profileBackgroundUploadDone(upload) {
    this.model.set("profile_background_upload_url", upload.url);
  }

  @action
  cardBackgroundUploadDone(upload) {
    this.model.set("card_background_upload_url", upload.url);
  }

  @action
  _updateUserFields() {
    const modelFields = this.model.get("user_fields");
    if (modelFields && this.userFields) {
      this.userFields.forEach((uf) => {
        const value = modelFields[uf.field.id.toString()];
        // Normalize empty arrays to null
        if (Array.isArray(value) && value.length === 0) {
          modelFields[uf.field.id.toString()] = null;
        }
      });
    }
  }
}
