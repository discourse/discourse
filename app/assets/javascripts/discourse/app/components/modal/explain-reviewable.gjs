import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ExplainReviewable extends Component {
  @service store;

  @tracked loading = true;
  @tracked reviewableExplanation = null;

  constructor() {
    super(...arguments);
    this.loadExplanation();
  }

  @action
  async loadExplanation() {
    try {
      const result = await this.store.find(
        "reviewable-explanation",
        this.args.model.reviewable.id
      );
      this.reviewableExplanation = result;
    } finally {
      this.loading = false;
    }
  }
}
