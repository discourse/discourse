import I18n from "I18n";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";

export default function userStatus(user, args) {
  if (!user) {
    return;
  }

  const currentUser = args?.hash?.currentUser;
  const name = escapeExpression(user.name);

  if (currentUser && user.admin && currentUser.staff) {
    return iconHTML("shield-alt", {
      label: I18n.t("user.admin", { user: name }),
    });
  }

  if (user.moderator) {
    return iconHTML("shield-alt", {
      label: I18n.t("user.moderator", { user: name }),
    });
  }
}
