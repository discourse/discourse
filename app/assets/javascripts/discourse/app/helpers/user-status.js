import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export default function userStatus(user, { currentUser } = {}) {
  if (!user) {
    return;
  }

  const name = escapeExpression(user.name);

  if (user.admin && currentUser?.staff) {
    return htmlSafe(
      iconHTML("shield-halved", {
        label: I18n.t("user.admin", { user: name }),
      })
    );
  }

  if (user.moderator) {
    return htmlSafe(
      iconHTML("shield-halved", {
        label: I18n.t("user.moderator", { user: name }),
      })
    );
  }
}
