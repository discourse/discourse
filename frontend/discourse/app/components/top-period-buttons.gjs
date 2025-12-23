/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import periodTitle from "discourse/helpers/period-title";

@classNames("top-title-buttons")
export default class TopPeriodButtons extends Component {
  @computed("period")
  get periods() {
    return this.site.get("periods").filter((p) => p !== this.period);
  }

  @action
  changePeriod(p) {
    this.action(p);
  }

  <template>
    {{#each this.periods as |p|}}
      <DButton
        @action={{fn this.changePeriod p}}
        @translatedLabel={{periodTitle p}}
        class="btn-default"
      />
    {{/each}}
  </template>
}
