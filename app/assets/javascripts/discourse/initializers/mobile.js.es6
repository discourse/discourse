import Mobile from "discourse/lib/mobile";
import { setResolverOption } from "discourse-common/resolver";

// Initializes the `Mobile` helper object.
export default {
  name: "mobile",
  after: "inject-objects",

  initialize(container) {
    Mobile.init();
    const site = container.lookup("site:main");

    site.set("mobileView", Mobile.mobileView);
    site.set("isMobileDevice", Mobile.isMobileDevice);

    setResolverOption("mobileView", Mobile.mobileView);
  }
};
