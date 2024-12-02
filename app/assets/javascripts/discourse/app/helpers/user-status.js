import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

export default function userStatus(user, { currentUser } = {}) {
  if (!user) {
    return;
  }

  const name = escapeExpression(user.name);

  if (user.admin && currentUser?.staff) {
    return htmlSafe(
      iconHTML("shield-halved", {
        label: i18n("user.admin", { user: name }),
      })
    );
  }

  if (user.moderator) {
    return htmlSafe(
      iconHTML("shield-halved", {
        label: i18n("user.moderator", { user: name }),
      })
    );
  }
}
