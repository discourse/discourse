import { h } from "virtual-dom";
import { formatUsername } from "discourse/lib/utilities";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-group-timezones-member", {
  tagName: "li.group-timezones-member",

  buildClasses(attrs) {
    return attrs.member.on_holiday ? "on-holiday" : "not-on-holiday";
  },

  html(attrs) {
    const { name, username, avatar_template } = attrs.member;

    return h(
      "a",
      {
        attributes: {
          class: "group-timezones-member-avatar",
          "data-user-card": username,
        },
      },
      avatarImg("small", {
        template: avatar_template,
        username: name || formatUsername(username),
      })
    );
  },
});
