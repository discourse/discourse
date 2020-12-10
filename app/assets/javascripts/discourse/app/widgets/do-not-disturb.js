import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

export default createWidget("do-not-disturb", {
  tagName: "div.do-not-disturb",

  html() {
    return [
      h("div#do-not-disturb-link", "Pause notifications"),
      h("div#do-not-disturb-popup", "POPUP"),
    ];
  },

  didRenderWidget() {
    ["do-not-disturb-link", "do-not-disturb-popup"].forEach((el) => {
      document.getElementById(el).addEventListener("mouseover", function () {
        document.getElementById("do-not-disturb-popup").style.display = "block";
      });
      document.getElementById(el).addEventListener("mouseout", function () {
        document.getElementById("do-not-disturb-popup").style.display = "none";
      });
    });
  },
});
