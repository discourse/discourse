import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class CustomDateRange extends Component {
  @tracked startDate = this.args.model.startDate;
  @tracked endDate = this.args.model.endDate;

  @action
  onChangeDateRange(range) {
    this.startDate = range.from;
    this.endDate = range.to;
  }

  @action
  updateDateRange() {
    this.args.model.setCustomDateRange(this.startDate, this.endDate);
    this.args.closeModal();
  }
}
