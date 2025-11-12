import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";
import { LEADERBOARD_PERIODS } from "discourse/plugins/discourse-gamification/discourse/components/gamification-leaderboard";

@selectKitOptions({
  filterable: true,
  allowAny: false,
})
@pluginApiIdentifiers("period-input")
@classNames("period-input", "period-input")
export default class PeriodInput extends ComboBoxComponent {
  @computed
  get content() {
    let periods = [];

    periods = periods.concat(
      LEADERBOARD_PERIODS.map((period, index) => ({
        name: i18n(`gamification.leaderboard.period.${period}`),
        id: index,
      }))
    );

    return periods;
  }
}
