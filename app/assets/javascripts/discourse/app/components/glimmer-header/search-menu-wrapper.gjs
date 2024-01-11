createWidget("glimmer-search-menu-wrapper", {
  services: ["search"],
  buildAttributes() {
    return { "data-click-outside": true, "aria-live": "polite" };
  },

  buildClasses() {
    return ["search-menu glimmer-search-menu"];
  },

  html() {
    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<SearchMenuPanel @closeSearchMenu={{@data.closeSearchMenu}} />`,
        {
          closeSearchMenu: this.closeSearchMenu.bind(this),
        }
      ),
    ];
  },

  closeSearchMenu() {
    this.sendWidgetAction("toggleSearchMenu");
    document.getElementById(SEARCH_BUTTON_ID)?.focus();
  },

  clickOutside() {
    this.closeSearchMenu();
  },
});
