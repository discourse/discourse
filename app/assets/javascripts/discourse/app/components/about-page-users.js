import Component from "@ember/component";
import { computed } from "@ember/object";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { userPath } from "discourse/lib/url";

export default Component.extend({
  usersTemplates: computed("users.[]", function () {
    return (this.users || []).map((user) => {
      const { name, username } = user;

      return {
        name,
        username,
        userPath: userPath(username),
        avatar: renderAvatar(user, {
          imageSize: "large",
          siteSettings: this.siteSettings,
        }),
        title: user.title || "",
        prioritizeName: prioritizeNameInUx(name),
      };
    });
  }),
});
