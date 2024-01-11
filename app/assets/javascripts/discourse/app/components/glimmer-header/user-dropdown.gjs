createWidget(
  "user-dropdown",
  Object.assign(
    {
      tagName: "li.header-dropdown-toggle.current-user",

      buildId() {
        return "current-user";
      },

      html(attrs) {
        return h(
          "button.icon.btn-flat",
          {
            attributes: {
              "aria-haspopup": true,
              "aria-expanded": attrs.active,
              href: attrs.user.path,
              "aria-label":
                (attrs.user.name || attrs.user.username) +
                I18n.t("user.account_possessive"),
              "data-auto-route": true,
            },
          },
          this.attach("header-notifications", attrs)
        );
      },
    },
    dropdown
  )
);

const dropdown = {
  buildClasses(attrs) {
    let classes = attrs.classNames || [];
    if (attrs.active) {
      classes.push("active");
    }

    return classes;
  },

  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    if (!this.attrs.active) {
      this.sendWidgetAction(this.attrs.action);
    }
  },
};
