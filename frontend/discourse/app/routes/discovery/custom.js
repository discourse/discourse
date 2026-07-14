import { applyBehaviorTransformer } from "discourse/lib/transformer";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscoveryCustomRoute extends DiscourseRoute {
  queryParams = {
    q: { refreshModel: true },
  };

  model(data) {
    return applyBehaviorTransformer("custom-homepage-model", () => null, {
      queryParams: data,
    });
  }
}
