import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",

  @computed("percentage")
  showPercentage(percentage) {
    return percentage.total >= 3;
  },

  // We do a little logic to choose which icon to display and which text
  @computed("user.flags_agreed", "user.flags_disagreed", "user.flags_ignored")
  percentage(agreed, disagreed, ignored) {
    let total = agreed + disagreed + ignored;
    let result = { total };

    if (total > 0) {
      result.agreed = Math.round((agreed / total) * 100);
      result.disagreed = Math.round((disagreed / total) * 100);
      result.ignored = Math.round((ignored / total) * 100);
    }

    let highest = Math.max(agreed, disagreed, ignored);
    if (highest === agreed) {
      result.icon = "thumbs-up";
      result.className = "agreed";
      result.label = `${result.agreed}%`;
    } else if (highest === disagreed) {
      result.icon = "thumbs-down";
      result.className = "disagreed";
      result.label = `${result.disagreed}%`;
    } else {
      result.icon = "external-link";
      result.className = "ignored";
      result.label = `${result.ignored}%`;
    }

    result.title = I18n.t("admin.flags.user_percentage.summary", {
      agreed: I18n.t("admin.flags.user_percentage.agreed", {
        count: result.agreed
      }),
      disagreed: I18n.t("admin.flags.user_percentage.disagreed", {
        count: result.disagreed
      }),
      ignored: I18n.t("admin.flags.user_percentage.ignored", {
        count: result.ignored
      }),
      count: total
    });

    return result;
  }
});
