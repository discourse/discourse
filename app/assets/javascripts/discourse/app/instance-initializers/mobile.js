import Mobile from "discourse/lib/mobile";
import { setResolverOption } from "discourse/resolver";

// Initializes the `Mobile` helper object.
export default {
  after: "inject-objects",

  initialize(owner) {
    if (owner.lookup("service:site-settings").viewport_based_mobile_mode) {
      return;
    }

    Mobile.init();
    setResolverOption("mobileView", Mobile.mobileView);
  },
};
