import { getOwner } from "discourse-common/lib/get-owner";
import deprecated from "discourse-common/lib/deprecated";

deprecated(
  "`discourse/lib/mobile` import is deprecated. Use `isMobileDevice`, `mobileView`, properties and `toggleMobileView` method on `service:site`."
);

function site() {
  // Use the "default owner"
  return getOwner().lookup("service:site");
}

const Mobile = {
  get isMobileDevice() {
    return site().isMobileDevice;
  },

  get mobileView() {
    return site().mobileView;
  },

  toggleMobileView() {
    return site().toggleMobileView();
  },
};

export function forceMobile() {
  site().mobileView = true;
}

export default Mobile;
