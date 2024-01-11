createWidget("header-icons", {
  services: ["search"],
  tagName: "ul.icons.d-header-icons",

  html(attrs) {
    if (this.siteSettings.login_required && !this.currentUser) {
      return [];
    }

    const icons = [];

    if (_extraHeaderIcons) {
      _extraHeaderIcons.forEach((icon) => {
        icons.push(this.attach(icon));
      });
    }

    const search = this.attach("header-dropdown", {
      title: "search.title",
      icon: "search",
      iconId: SEARCH_BUTTON_ID,
      action: "toggleSearchMenu",
      active: attrs.searchVisible || this.search.visible,
      href: getURL("/search"),
      classNames: ["search-dropdown"],
    });

    icons.push(search);

    const hamburger = this.attach("header-dropdown", {
      title: "hamburger_menu",
      icon: "bars",
      iconId: "toggle-hamburger-menu",
      active: attrs.hamburgerVisible,
      action: "toggleHamburger",
      href: "",
      classNames: ["hamburger-dropdown"],
    });

    if (!attrs.sidebarEnabled || this.site.mobileView) {
      icons.push(hamburger);
    }

    if (attrs.user) {
      icons.push(
        this.attach("user-dropdown", {
          active: attrs.userVisible,
          action: "toggleUserMenu",
          user: attrs.user,
        })
      );
    }

    return icons;
  },
});
