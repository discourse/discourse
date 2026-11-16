import { trustHTML } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default function userStatus(user, { currentUser, showName } = {}) {
  if (!user) {
    return;
  }

  const name = escapeExpression(showName ? user.name : user.username);

  if (user.admin && currentUser?.staff) {
    return trustHTML(
      iconHTML("shield-halved", {
        label: i18n("user.admin", { user: name }),
      })
    );
  }

  if (user.moderator) {
    return trustHTML(
      iconHTML("shield-halved", {
        label: i18n("user.moderator", { user: name }),
      })
    );
  }
}
