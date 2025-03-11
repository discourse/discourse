import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
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
}
{{#each this.periods as |p|}}
  <DButton
    @action={{fn this.changePeriod p}}
    @translatedLabel={{period-title p}}
    class="btn-default"
  />
{{/each}}