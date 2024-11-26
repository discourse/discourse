import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class UserFlagPercentage extends Component {
  @discourseComputed("percentage")
  showPercentage(percentage) {
    return percentage.total >= 3;
  }

  // We do a little logic to choose which icon to display and which text
  @discourseComputed("agreed", "disagreed", "ignored")
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
      result.icon = "up-right-from-square";
      result.className = "ignored";
      result.label = `${result.ignored}%`;
    }

    result.title = i18n("review.user_percentage.summary", {
      agreed: i18n("review.user_percentage.agreed", {
        count: result.agreed,
      }),
      disagreed: i18n("review.user_percentage.disagreed", {
        count: result.disagreed,
      }),
      ignored: i18n("review.user_percentage.ignored", {
        count: result.ignored,
      }),
      count: total,
    });

    return result;
  }
}
