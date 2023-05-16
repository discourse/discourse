import Mobile from "discourse/lib/mobile";
import { setResolverOption } from "discourse-common/resolver";

// Initializes the `Mobile` helper object.
export default {
  name: "mobile",
  after: "inject-objects",

  initialize(container) {
    Mobile.init();
    const site = container.lookup("service:site");

    site.set("mobileView", Mobile.mobileView);
    site.set("desktopView", !Mobile.mobileView);
    site.set("isMobileDevice", Mobile.isMobileDevice);

    setResolverOption("mobileView", Mobile.mobileView);
  },
};
