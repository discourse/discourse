createWidget("hamburger-dropdown-wrapper", {
  buildAttributes() {
    return { "data-click-outside": true };
  },

  html() {
    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<Sidebar::HamburgerDropdown />`
      ),
    ];
  },

  click(event) {
    if (
      event.target.closest(".sidebar-section-header-button") ||
      event.target.closest(".sidebar-section-link-button") ||
      event.target.closest(".sidebar-section-link")
    ) {
      this.sendWidgetAction("toggleHamburger");
    }
  },

  clickOutside(e) {
    if (
      e.target.classList.contains("header-cloak") &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      const finishPosition =
        document.querySelector("html").classList["direction"] === "rtl"
          ? "340px"
          : "-340px";
      panel
        .animate([{ transform: `translate3d(${finishPosition}, 0, 0)` }], {
          duration: 200,
          fill: "forwards",
          easing: "ease-in",
        })
        .finished.then(() => {
          if (isTesting()) {
            this.sendWidgetAction("toggleHamburger");
          } else {
            discourseLater(() => this.sendWidgetAction("toggleHamburger"));
          }
        });
      headerCloak.animate([{ opacity: 0 }], {
        duration: 200,
        fill: "forwards",
        easing: "ease-in",
      });
    } else {
      this.sendWidgetAction("toggleHamburger");
    }
  },
});
