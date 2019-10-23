import Controller from "@ember/controller";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

const EMAIL_LEVELS = {
  ALWAYS: 0,
  ONLY_WHEN_AWAY: 1,
  NEVER: 2
};

export default Controller.extend(PreferencesTabController, {
  emailMessagesLevelAway: Ember.computed.equal(
    "model.user_option.email_messages_level",
    EMAIL_LEVELS.ONLY_WHEN_AWAY
  ),
  emailLevelAway: Ember.computed.equal(
    "model.user_option.email_level",
    EMAIL_LEVELS.ONLY_WHEN_AWAY
  ),

  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "email_level",
      "email_messages_level",
      "mailing_list_mode",
      "mailing_list_mode_frequency",
      "email_digests",
      "email_in_reply_to",
      "email_previous_replies",
      "digest_after_minutes",
      "include_tl0_in_digests"
    ];

    this.previousRepliesOptions = [
      { name: I18n.t("user.email_previous_replies.always"), value: 0 },
      { name: I18n.t("user.email_previous_replies.unless_emailed"), value: 1 },
      { name: I18n.t("user.email_previous_replies.never"), value: 2 }
    ];

    this.emailLevelOptions = [
      { name: I18n.t("user.email_level.always"), value: EMAIL_LEVELS.ALWAYS },
      {
        name: I18n.t("user.email_level.only_when_away"),
        value: EMAIL_LEVELS.ONLY_WHEN_AWAY
      },
      { name: I18n.t("user.email_level.never"), value: EMAIL_LEVELS.NEVER }
    ];

    this.digestFrequencies = [
      { name: I18n.t("user.email_digests.every_30_minutes"), value: 30 },
      { name: I18n.t("user.email_digests.every_hour"), value: 60 },
      { name: I18n.t("user.email_digests.daily"), value: 1440 },
      { name: I18n.t("user.email_digests.weekly"), value: 10080 },
      { name: I18n.t("user.email_digests.every_month"), value: 43200 },
      { name: I18n.t("user.email_digests.every_six_months"), value: 259200 }
    ];
  },

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
      { name: this.frequencyEstimate, value: 1 },
      { name: I18n.t("user.mailing_list_mode.individual_no_echo"), value: 2 }
    ];
  },

  @computed()
  emailFrequencyInstructions() {
    if (this.siteSettings.email_time_window_mins) {
      return I18n.t("user.email.frequency", {
        count: this.siteSettings.email_time_window_mins
      });
    } else {
      return I18n.t("user.email.frequency_immediately");
    }
  },

  actions: {
    save() {
      this.set("saved", false);
      return this.model
        .save(this.saveAttrNames)
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    }
  }
});
