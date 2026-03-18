import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";

function _handleLastCheckedByEvent(event) {
  ajax(`/append-last-checked-by/${event.currentTarget.postId}`, {
    type: "PUT",
  }).catch(popupAjaxError);
}

function _initializeAppendByListener(api) {
  if (api.getCurrentUser()) {
    api.decorateCookedElement(_decorateCheckedButton, {
      id: "discourse-automation",
    });
  }
}

function _decorateCheckedButton(element, postDecorator) {
  if (!postDecorator) {
    return;
  }

  const elems = element.querySelectorAll(".btn-checked");
  const postModel = postDecorator.getModel();

  Array.from(elems).forEach((elem) => {
    elem.postId = postModel.id;
    elem.addEventListener("click", _handleLastCheckedByEvent, false);
  });
}

export default {
  name: "append-by-listener",

  initialize() {
    withPluginApi(_initializeAppendByListener);
  },
};
