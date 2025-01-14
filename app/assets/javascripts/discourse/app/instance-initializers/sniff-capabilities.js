export default {
  initialize(owner) {
    const caps = owner.lookup("service:capabilities");
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

    if (caps.isTablet) {
      html.classList.add("tablet-device");
    }
  },
};
