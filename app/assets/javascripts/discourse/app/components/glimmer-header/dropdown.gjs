createWidget(
  "header-dropdown",
  Object.assign(
    {
      tagName: "li.header-dropdown-toggle",

      html(attrs) {
        const title = I18n.t(attrs.title);

        const body = [iconNode(attrs.icon)];
        if (attrs.contents) {
          body.push(attrs.contents.call(this));
        }

        return h(
          "button.icon.btn-flat",
          {
            attributes: {
              "aria-expanded": attrs.active,
              "aria-haspopup": true,
              href: attrs.href,
              "data-auto-route": true,
              title,
              "aria-label": title,
              id: attrs.iconId,
            },
          },
          body
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
