export default {
  name: "sniff-capabilities",
  after: "export-application-global",

  initialize(container) {
    const caps = container.lookup("service:capabilities");
    const html = document.documentElement;

    if (caps.touch) {
      html.classList.add("touch", "discourse-touch");
    } else {
      html.classList.add("no-touch", "discourse-no-touch");
    }
  },
};
