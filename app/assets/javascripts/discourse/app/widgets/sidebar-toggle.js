import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

export default createWidget("sidebar-toggle", {
  tagName: "span.header-sidebar-toggle",

  html() {
    return h(
      "span",
      this.attach("button", {
        title: "",
        icon: "bars",
        action: "toggleSidebar",
        className: "btn btn-flat",
      })
    );
  },
});
