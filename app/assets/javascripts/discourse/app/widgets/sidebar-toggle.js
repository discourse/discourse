import { createWidget } from "discourse/widgets/widget";

export default createWidget("sidebar-toggle", {
  tagName: "span.header-sidebar-toggle",

  html() {
    const attrs = this.attrs;
    return [
      this.attach("button", {
        title: "sidebar.title",
        icon: "bars",
        action: this.site.narrowDesktopView
          ? "toggleHamburger"
          : "toggleSidebar",
        className: `btn btn-flat btn-sidebar-toggle ${
          this.site.narrowDesktopView ? "narrow-desktop" : ""
        }`,
        ariaExpanded: attrs.showSidebar ? "true" : "false",
        ariaControls: "d-sidebar",
      }),
    ];
  },
});
