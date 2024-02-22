export default {
  initialize(owner) {
    const caps = owner.lookup("service:capabilities");
    const html = document.documentElement;

    if (caps.touch) {
      html.classList.add("touch", "discourse-touch");
    } else {
      html.classList.add("no-touch", "discourse-no-touch");
    }
  },
};
