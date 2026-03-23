import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { addUniqueValuesToArray } from "discourse/lib/array-tools";
import { flattenBoost, PAGE_SIZE } from "../../routes/user-activity/boosts";

export default class UserActivityBoostsController extends Controller {
  @tracked canLoadMore = true;
  @tracked loading = false;

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loading) {
      return [];
    }

    this.loading = true;

    try {
      const lastBoost = this.model[this.model.length - 1];
      const beforeBoostId = lastBoost?.boost_id;

      const result = await ajax(
        `/discourse-boosts/users/${this.username}/${this.boostsUrl}.json`,
        { data: { before_boost_id: beforeBoostId } }
      );

      const boosts = result.boosts || [];
      const flattened = boosts.map(flattenBoost);

      addUniqueValuesToArray(this.model, flattened);

      if (flattened.length < PAGE_SIZE) {
        this.canLoadMore = false;
      }

      return flattened;
    } finally {
      this.loading = false;
    }
  }
}
