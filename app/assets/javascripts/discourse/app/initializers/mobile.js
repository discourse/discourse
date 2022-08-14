import { setResolverOption } from "discourse-common/resolver";
import { setResolverOption as setLegacyResolverOption } from "discourse-common/lib/legacy-resolver";

// Initializes the `mobileView` resolver option
export default {
  name: "mobile",
  after: "inject-objects",

  initialize(container) {
    const site = container.lookup("service:site");

    setResolverOption("mobileView", site.mobileView);
    setLegacyResolverOption("mobileView", site.mobileView);
  },
};
