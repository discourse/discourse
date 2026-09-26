import { lookup } from "discourse/lib/service";
import CapabilitiesService from "discourse/services/capabilities";
export default {
  initialize(owner) {
    const caps = lookup(owner, CapabilitiesService);
    const html = document.documentElement;

    if (caps.touch) {
      html.classList.add("touch", "discourse-touch");
    } else {
      html.classList.add("no-touch", "discourse-no-touch");
    }

    if (caps.isIpadOS) {
      html.classList.add("ipados-device");
    }

    if (caps.isIOS) {
      html.classList.add("ios-device");
    }
  },
};
