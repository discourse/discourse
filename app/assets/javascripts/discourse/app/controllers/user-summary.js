import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { duration } from "discourse/lib/formatter";
import discourseComputed from "discourse-common/utils/decorators";

// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default Controller.extend({
  userController: controller("user"),
  user: alias("userController.model"),
  siteSettings: service(),
  currentUser: service(),

  init() {
    this._super(...arguments);
    this.fetchProfileViews();
  },

  async fetchProfileViews() {
    const profileViews = await ajax("/u/profile-views.json");
    this.set("profileViews", profileViews);
    this.set("firstUser", profileViews.views?.[0]);
    this.set("secondUser", profileViews.views?.[1]);
  },

  setAdmitsReceivedWithHash(
    topCollege = null,
    admitsAwaited = [],
    admitsReceived = []
  ) {
    let allColleges = [];

    // Handle the single college
    if (topCollege) {
      allColleges.push({ name: topCollege, topText: "Top Preference" });
    }

    // Handle the lists of colleges
    allColleges = allColleges.concat(
      [].concat(admitsAwaited || []).map((name) => ({
        name,
        type: "await",
        topText: "Admit Awaited",
      })),
      [].concat(admitsReceived || []).map((name) => ({
        name,
        topText: "Admit Received",
      }))
    );

    Promise.all(
      allColleges.map(async (college) => {
        const hash = await this.sha1(college.name);
        return {
          ...college,
          hash,
        };
      })
    ).then((results) => {
      this.set("admitsReceivedWithHash", results);
    });
  },

  sha1(data) {
    const encoder = new TextEncoder();
    const encodedData = encoder.encode(data);
    return crypto.subtle.digest("SHA-1", encodedData).then((hashBuffer) => {
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
    });
  },

  @discourseComputed("profileViews")
  firstUser(profileViews) {
    return profileViews.views?.[0];
  },

  @discourseComputed("profileViews")
  secondUser(profileViews) {
    return profileViews.views?.[1];
  },

  @discourseComputed("model.badges.length")
  moreBadges(badgesLength) {
    return badgesLength >= MAX_BADGES;
  },

  @discourseComputed("model.time_read")
  timeRead(timeReadSeconds) {
    return duration(timeReadSeconds, { format: "tiny" });
  },

  @discourseComputed("model.time_read")
  timeReadMedium(timeReadSeconds) {
    return duration(timeReadSeconds, { format: "medium" });
  },

  @discourseComputed("model.time_read", "model.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  },

  @discourseComputed("model.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return recentTimeReadSeconds > 0
      ? duration(recentTimeReadSeconds, { format: "tiny" })
      : null;
  },

  @discourseComputed("model.recent_time_read")
  recentTimeReadMedium(recentTimeReadSeconds) {
    return recentTimeReadSeconds > 0
      ? duration(recentTimeReadSeconds, { format: "medium" })
      : null;
  },

  @discourseComputed("user.custom_fields")
  topCollege(customFields) {
    // dummy field to trigger computation
    this.setAdmitsReceivedWithHash(
      customFields?.[this.siteSettings.college_top_preference_field],
      customFields?.[this.siteSettings.college_admits_awaited_field],
      customFields?.[this.siteSettings.college_admits_received_field]
    );
  },

  @discourseComputed("user.custom_fields")
  course(customFields) {
    return customFields?.[this.siteSettings.user_enrollment_field];
  },
});
