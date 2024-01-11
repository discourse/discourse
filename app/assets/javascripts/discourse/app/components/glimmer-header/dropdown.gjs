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
