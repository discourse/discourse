import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { avatarFor } from "discourse/widgets/post";
import { userPath } from "discourse/lib/url";
import { formatUsername, escapeExpression } from "discourse/lib/utilities";
import { normalize } from "discourse/components/user-info";

createWidget("user-info-list", {
  tagName: "div.users",

  html(attrs) {
    return attrs.users.map(user => {
      return this.attach("user-info", user);
    });
  }
});
createWidget("user-info", {
  tagName: "div.user-info",

  buildClasses(attrs) {
    return attrs.size || "small";
  },

  buildAttributes(attrs) {
    return {
      "data-username": attrs.username
    };
  },

  html(attrs) {
    const userAvatar = h(
      "div.user-image",
      h(
        "div.user-image-inner",
        avatarFor.call(this, "large", {
          template: attrs.avatar_template,
          username: attrs.username,
          name: attrs.name,
          url: userPath(attrs.username)
        })
      )
    );
    let name = "";
    if (attrs.name && normalize(attrs.username) !== normalize(name)) {
      name = attrs.name;
    }
    const userDetails = h("div.user-detail", [
      h("div.name-line", [
        h(
          "span.username",
          h(
            "a",
            {
              href: userPath(attrs.username),
              "data-user-card": attrs.username
            },
            formatUsername(attrs.username)
          )
        ),
        h("span.name", name)
      ]),
      h("div.title", user.title)
    ]);

    return [userAvatar, userDetails];
  }
});
