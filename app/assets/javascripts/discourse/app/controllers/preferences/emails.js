import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const EMAIL_LEVELS = {
  ALWAYS: 0,
  ONLY_WHEN_AWAY: 1,
  NEVER: 2,
};

export default class EmailsController extends Controller {
  subpageTitle = i18n("user.preferences_nav.emails");

  @equal("model.user_option.email_messages_level", EMAIL_LEVELS.ONLY_WHEN_AWAY)
  emailMessagesLevelAway;

  @equal("model.user_option.email_level", EMAIL_LEVELS.ONLY_WHEN_AWAY)
  emailLevelAway;

  saveAttrNames = [
    "email_level",
    "email_messages_level",
    "mailing_list_mode",
    "mailing_list_mode_frequency",
    "email_digests",
    "email_in_reply_to",
    "email_previous_replies",
    "digest_after_minutes",
    "include_tl0_in_digests",
  ];

  previousRepliesOptions = [
    { name: i18n("user.email_previous_replies.always"), value: 0 },
    { name: i18n("user.email_previous_replies.unless_emailed"), value: 1 },
    { name: i18n("user.email_previous_replies.never"), value: 2 },
  ];

  emailLevelOptions = [
    { name: i18n("user.email_level.always"), value: EMAIL_LEVELS.ALWAYS },
    {
      name: i18n("user.email_level.only_when_away"),
      value: EMAIL_LEVELS.ONLY_WHEN_AWAY,
    },
    { name: i18n("user.email_level.never"), value: EMAIL_LEVELS.NEVER },
  ];

  digestFrequencies = [
    { name: i18n("user.email_digests.every_30_minutes"), value: 30 },
    { name: i18n("user.email_digests.every_hour"), value: 60 },
    { name: i18n("user.email_digests.daily"), value: 1440 },
    { name: i18n("user.email_digests.weekly"), value: 10080 },
    { name: i18n("user.email_digests.every_month"), value: 43200 },
    { name: i18n("user.email_digests.every_six_months"), value: 259200 },
  ];

  @discourseComputed()
  frequencyEstimate() {
    let estimate = this.get("model.mailing_list_posts_per_day");
    if (!estimate || estimate < 2) {
      return i18n("user.mailing_list_mode.few_per_day");
    } else {
      return i18n("user.mailing_list_mode.many_per_day", {
        dailyEmailEstimate: estimate,
      });
    }
  }

  @discourseComputed()
  mailingListModeOptions() {
    return [
      { name: this.frequencyEstimate, value: 1 },
      { name: i18n("user.mailing_list_mode.individual_no_echo"), value: 2 },
    ];
  }

  @discourseComputed()
  emailFrequencyInstructions() {
    return this.siteSettings.email_time_window_mins
      ? i18n("user.email.frequency", {
          count: this.siteSettings.email_time_window_mins,
        })
      : null;
  }

  @action
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
