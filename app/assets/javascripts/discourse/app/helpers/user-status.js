import I18n from "I18n";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

export default function userStatus(user, { currentUser } = {}) {
  if (!user) {
    return;
  }

  const name = escapeExpression(user.name);

  if (user.admin && currentUser?.staff) {
    return htmlSafe(
      iconHTML("shield-alt", {
        label: I18n.t("user.admin", { user: name }),
      })
    );
  }

  if (user.moderator) {
    return htmlSafe(
      iconHTML("shield-alt", {
        label: I18n.t("user.moderator", { user: name }),
      })
    );
  }
}
