import Component from "@ember/component";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class RemindAssignsFrequency extends Component {
  @discourseComputed(
    "user.custom_fields.remind_assigns_frequency",
    "siteSettings.remind_assigns_frequency"
  )
  selectedFrequency(userAssignsFrequency, siteDefaultAssignsFrequency) {
    if (
      this.availableFrequencies
        .map((freq) => freq.value)
        .includes(userAssignsFrequency)
    ) {
      return userAssignsFrequency;
    }

    return siteDefaultAssignsFrequency;
  }

  @discourseComputed("user.reminders_frequency")
  availableFrequencies(userRemindersFrequency) {
    return userRemindersFrequency.map((freq) => ({
      name: i18n(freq.name),
      value: freq.value,
      selected: false,
    }));
  }
}
