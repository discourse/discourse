import { createWidget } from "discourse/widgets/widget";

export default createWidget("sidebar-toggle", {
  tagName: "span.header-sidebar-toggle",

  html() {
    return [
      this.attach("button", {
        title: "",
        icon: "bars",
        action: "toggleSidebar",
        className: "btn btn-flat btn-sidebar-toggle",
      }),
    ];
  },
});
