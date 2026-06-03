import { service } from "@ember/service";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscoveryCustomRoute extends DiscourseRoute {
  @service blocks;

  queryParams = {
    q: { refreshModel: true },
  };

  // Aborts the previous prepare when a new transition into this route starts
  // (e.g. a query-param refresh) so a superseded load doesn't keep running.
  #prepareController;

  model(data) {
    return applyBehaviorTransformer("custom-homepage-model", () => null, {
      queryParams: data,
    });
  }

  async afterModel() {
    // Resolve the homepage blocks' declared data inside the transition so they
    // paint filled-in (no per-block loading state). Resolution is served from
    // server-inlined preload payloads when present, otherwise fetched here.
    this.#prepareController?.abort();
    this.#prepareController = new AbortController();

    await this.blocks.prepareData("homepage-blocks", {
      params: this.paramsFor(this.routeName),
      signal: this.#prepareController.signal,
    });
  }
}
