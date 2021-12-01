import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { makeArray } from "discourse-common/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

function _initializeDiscourseAutomation(api) {
  _initializeGLobalUserNotices(api);
}

function _initializeGLobalUserNotices(api) {
  const currentUser = api.getCurrentUser();

  makeArray(currentUser?.global_notices).forEach(userGlobalNotice => {
    api.addGlobalNotice("", userGlobalNotice.identifier, {
      html: userGlobalNotice.notice,
      level: userGlobalNotice.level,
      dismissable: true,
      dismissDuration: moment.duration(1, "week"),
      onDismiss() {
        ajax(`/user-global-notices/${userGlobalNotice.id}.json`, {
          type: "DELETE"
        }).catch(popupAjaxError);
      }
    });
  });
}

export default {
  name: "discourse-automation",

  initialize() {
    withPluginApi("0.8.24", _initializeDiscourseAutomation);
  }
};
