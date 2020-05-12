import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import EmberObject from "@ember/object";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cookAsync } from "discourse/lib/text";
import { ajax } from "discourse/lib/ajax";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
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
      "timezone"
    ];
  },

  @discourseComputed("model.user_fields.@each.value")
  userFields() {
    let siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("model.user_fields");

      // Staff can edit fields that are not `editable`
      if (!this.get("currentUser.staff")) {
        siteUserFields = siteUserFields.filterBy("editable", true);
      }
      return siteUserFields.sortBy("position").map(function(field) {
        const value = userFields
          ? userFields[field.get("id").toString()]
          : null;
        return EmberObject.create({ value, field });
      });
    }
  },

  @discourseComputed("model.can_change_bio")
  canChangeBio(canChangeBio) {
    return canChangeBio;
  },

  @discourseComputed("model.can_change_location")
  canChangeLocation(canChangeLocation) {
    return canChangeLocation;
  },

  @discourseComputed("model.can_change_website")
  canChangeWebsite(canChangeWebsite) {
    return canChangeWebsite;
  },

  actions: {
    showFeaturedTopicModal() {
      showModal("feature-topic-on-profile", {
        model: this.model,
        title: "user.feature_topic_on_profile.title"
      });
    },

    clearFeaturedTopicFromProfile() {
      bootbox.confirm(
        I18n.t("user.feature_topic_on_profile.clear.warning"),
        result => {
          if (result) {
            ajax(`/u/${this.model.username}/clear-featured-topic`, {
              type: "PUT"
            })
              .then(() => {
                this.model.set("featured_topic", null);
              })
              .catch(popupAjaxError);
          }
        }
      );
    },

    useCurrentTimezone() {
      this.model.set("user_option.timezone", moment.tz.guess());
    },

    save() {
      this.set("saved", false);

      const model = this.model,
        userFields = this.userFields;

      // Update the user fields
      if (!isEmpty(userFields)) {
        const modelFields = model.get("user_fields");
        if (!isEmpty(modelFields)) {
          userFields.forEach(function(uf) {
            modelFields[uf.get("field.id").toString()] = uf.get("value");
          });
        }
      }

      return model
        .save(this.saveAttrNames)
        .then(() => {
          // update the timezone in memory so we can use the new
          // one if we change routes without reloading the user
          if (this.currentUser.id === this.model.id) {
            this.currentUser.changeTimezone(this.model.user_option.timezone);
          }

          cookAsync(model.get("bio_raw"))
            .then(() => {
              model.set("bio_cooked");
              this.set("saved", true);
            })
            .catch(popupAjaxError);
        })
        .catch(popupAjaxError);
    }
  }
});
