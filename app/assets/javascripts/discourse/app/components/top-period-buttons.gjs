import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import periodTitle from "discourse/helpers/period-title";
import discourseComputed from "discourse/lib/decorators";

@classNames("top-title-buttons")
export default class TopPeriodButtons extends Component {
  @discourseComputed("period")
  periods(period) {
    return this.site.get("periods").filter((p) => p !== period);
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
