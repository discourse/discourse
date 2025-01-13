import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { makeArray } from "discourse/lib/helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

let _lastCheckedByHandlers = {};

function _handleLastCheckedByEvent(event) {
  ajax(`/append-last-checked-by/${event.currentTarget.postId}`, {
    type: "PUT",
  }).catch(popupAjaxError);
}

function _cleanUp() {
  Object.values(_lastCheckedByHandlers || {}).forEach((handler) => {
    handler.removeEventListener("click", _handleLastCheckedByEvent);
  });

  _lastCheckedByHandlers = {};
}

function _initializeDiscourseAutomation(api) {
  _initializeGLobalUserNotices(api);

  if (api.getCurrentUser()) {
    api.decorateCookedElement(_decorateCheckedButton, {
      id: "discourse-automation",
    });

    api.cleanupStream(_cleanUp);
  }
}

function _decorateCheckedButton(element, postDecorator) {
  if (!postDecorator) {
    return;
  }

  const elems = element.querySelectorAll(".btn-checked");
  const postModel = postDecorator.getModel();

  Array.from(elems).forEach((elem) => {
    const postId = postModel.id;
    elem.postId = postId;

    if (_lastCheckedByHandlers[postId]) {
      _lastCheckedByHandlers[postId].removeEventListener(
        "click",
        _handleLastCheckedByEvent,
        false
      );
      delete _lastCheckedByHandlers[postId];
    }

    _lastCheckedByHandlers[postId] = elem;
    elem.addEventListener("click", _handleLastCheckedByEvent, false);
  });
}

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
    withPluginApi("0.8.24", _initializeDiscourseAutomation);
  },
};
