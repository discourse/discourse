/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@classNames("penalty-history")
export default class AdminPenaltyHistory extends Component {
  @computed("user.penalty_counts.suspended")
  get suspendedCountClass() {
    if (this.user?.penalty_counts?.suspended > 0) {
      return "danger";
    }
    return "";
  }

  @computed("user.penalty_counts.silenced")
  get silencedCountClass() {
    if (this.user?.penalty_counts?.silenced > 0) {
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
