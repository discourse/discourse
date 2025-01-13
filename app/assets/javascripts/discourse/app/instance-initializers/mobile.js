import Mobile from "discourse/lib/mobile";
import { setResolverOption } from "discourse/resolver";

// Initializes the `Mobile` helper object.
export default {
  after: "inject-objects",

  initialize(owner) {
    Mobile.init();
    const site = owner.lookup("service:site");

    site.set("mobileView", Mobile.mobileView);
    site.set("desktopView", !Mobile.mobileView);
    site.set("isMobileDevice", Mobile.isMobileDevice);

    setResolverOption("mobileView", Mobile.mobileView);
  },
};
