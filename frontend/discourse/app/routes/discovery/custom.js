import { applyBehaviorTransformer } from "discourse/lib/transformer";
import { defaultHomepage } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscoveryCustomRoute extends DiscourseRoute {
  queryParams = {
    q: { refreshModel: true },
  };

  beforeModel() {
    if (defaultHomepage() !== "custom") {
      return this.replaceWith("discovery.index");
    }
  }

  model(data) {
    return applyBehaviorTransformer("custom-homepage-model", () => null, {
      queryParams: data,
    });
  }
}
