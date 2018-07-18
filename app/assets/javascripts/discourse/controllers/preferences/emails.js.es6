import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: [
    "email_always",
    "mailing_list_mode",
    "mailing_list_mode_frequency",
    "email_digests",
    "email_direct",
    "email_in_reply_to",
    "email_private_messages",
    "email_previous_replies",
    "digest_after_minutes",
    "include_tl0_in_digests"
  ],

  @computed()
  frequencyEstimate() {
    var estimate = this.get("model.mailing_list_posts_per_day");
    if (!estimate || estimate < 2) {
      return I18n.t("user.mailing_list_mode.few_per_day");
    } else {
      return I18n.t("user.mailing_list_mode.many_per_day", {
        dailyEmailEstimate: estimate
      });
    }
  },

  @computed()
  mailingListModeOptions() {
    return [
      { name: this.get("frequencyEstimate"), value: 1 },
      { name: I18n.t("user.mailing_list_mode.individual_no_echo"), value: 2 }
    ];
  },

  previousRepliesOptions: [
    { name: I18n.t("user.email_previous_replies.always"), value: 0 },
    { name: I18n.t("user.email_previous_replies.unless_emailed"), value: 1 },
    { name: I18n.t("user.email_previous_replies.never"), value: 2 }
  ],

  digestFrequencies: [
    { name: I18n.t("user.email_digests.every_30_minutes"), value: 30 },
    { name: I18n.t("user.email_digests.every_hour"), value: 60 },
    { name: I18n.t("user.email_digests.daily"), value: 1440 },
    { name: I18n.t("user.email_digests.every_three_days"), value: 4320 },
    { name: I18n.t("user.email_digests.weekly"), value: 10080 },
    { name: I18n.t("user.email_digests.every_two_weeks"), value: 20160 }
  ],

  actions: {
    save() {
      this.set("saved", false);
      return this.get("model")
        .save(this.get("saveAttrNames"))
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    }
  }
});
