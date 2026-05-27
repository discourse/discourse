import { trustHTML } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default function userStatus(user, { currentUser } = {}) {
  if (!user) {
    return;
  }

  const name = escapeExpression(user.name);

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
