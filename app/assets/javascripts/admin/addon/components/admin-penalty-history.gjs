import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@classNames("penalty-history")
export default class AdminPenaltyHistory extends Component {
  @discourseComputed("user.penalty_counts.suspended")
  suspendedCountClass(count) {
    if (count > 0) {
      return "danger";
    }
    return "";
  }

  @discourseComputed("user.penalty_counts.silenced")
  silencedCountClass(count) {
    if (count > 0) {
      return "danger";
    }
    return "";
  }

  <template>
    <div
      class="suspended-count {{this.suspendedCountClass}}"
      title={{i18n "admin.user.last_six_months"}}
    >
      <label>{{i18n "admin.user.suspended_count"}}</label>
      <span>{{this.user.penalty_counts.suspended}}</span>
    </div>
    <div
      class="silenced-count {{this.silencedCountClass}}"
      title={{i18n "admin.user.last_six_months"}}
    >
      <label>{{i18n "admin.user.silenced_count"}}</label>
      <span>{{this.user.penalty_counts.silenced}}</span>
    </div>
  </template>
}
