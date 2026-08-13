import { modifier } from "ember-modifier";

export default modifier((element, [html]) => {
  if (!html) {
    return;
  }

  element.querySelectorAll("a[href]").forEach((link) => {
    link.target = "_blank";
    link.relList.add("noopener");
  });
});
