import Component from "@ember/component";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import { normalize } from "discourse/components/user-info";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { computed } from "@ember/object";

export default Component.extend({
  usersTemplates: computed("users.[]", function() {
    return (this.users || []).map(user => {
      let name = "";
      if (user.name && normalize(user.username) !== normalize(user.name)) {
        name = user.name;
      }

      return {
        username: user.username,
        name,
        userPath: userPath(user.username),
        avatar: renderAvatar(user, { imageSize: "large" }),
        title: user.title || "",
        formatedUsername: formatUsername(user.username)
      };
    });
  })
});
