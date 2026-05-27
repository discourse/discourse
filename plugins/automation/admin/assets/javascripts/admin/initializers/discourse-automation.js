import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { makeArray } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

function _initializeGLobalUserNotices(api) {
  const currentUser = api.getCurrentUser();

  makeArray(currentUser?.global_notices).forEach((userGlobalNotice) => {
    api.addGlobalNotice("", userGlobalNotice.identifier, {
      html: userGlobalNotice.notice,
      level: userGlobalNotice.level,
      dismissable: true,
      dismissDuration: moment.duration(1, "week"),
      onDismiss() {
        ajax(`/user-global-notices/${userGlobalNotice.id}.json`, {
          type: "DELETE",
        }).catch(popupAjaxError);
      },
    });
  });
}

export default {
  name: "discourse-automation",

  initialize() {
    withPluginApi(_initializeGLobalUserNotices);
  },
};
