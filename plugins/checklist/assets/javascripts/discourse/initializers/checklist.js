import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import richEditorExtension from "../../lib/rich-editor-extension";

function setCheckboxState(checkbox, checked) {
  checkbox.classList.toggle("checked", checked);
  checkbox.classList.toggle("fa-square-o", !checked);
  checkbox.classList.toggle("fa-square-check-o", checked);
}

function onChecklistMessage(data) {
  const postElement = document.querySelector(
    `article[data-post-id="${data.post_id}"]`
  );
  if (!postElement) {
    return;
  }

  const checkbox = postElement.querySelector(
    `.chcklst-box[data-chk-off="${data.checkbox_offset}"]`
  );
  if (checkbox) {
    setCheckboxState(checkbox, data.checked);
  }
}

function initializePlugin(api) {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings.checklist_enabled) {
    api.decorateCookedElement(checklistSyntax);
    api.registerRichEditorExtension(richEditorExtension);

    // Subscribe to topic-specific checklist updates
    api.modifyClass(
      "controller:topic",
      (Superclass) =>
        class extends Superclass {
          subscribe() {
            super.subscribe(...arguments);
            this.messageBus.subscribe(
              `/checklist/${this.model.id}`,
              onChecklistMessage
            );
          }

          unsubscribe() {
            this.messageBus.unsubscribe(
              `/checklist/${this.model.id}`,
              onChecklistMessage
            );
            super.unsubscribe(...arguments);
          }
        }
    );
  }
}

function isWhitespaceNode(node) {
  return node.nodeType === 3 && node.nodeValue.match(/^\s*$/);
}

function hasPrecedingContent(node) {
  let sibling = node.previousSibling;
  while (sibling) {
    if (!isWhitespaceNode(sibling)) {
      return true;
    }
    sibling = sibling.previousSibling;
  }
  return false;
}

function addUlClasses(boxes) {
  boxes.forEach((val) => {
    let parent = val.parentElement;
    if (
      parent.nodeName === "P" &&
      parent.parentElement.firstElementChild === parent
    ) {
      parent = parent.parentElement;
    }

    if (
      parent.nodeName === "LI" &&
      parent.parentElement.nodeName === "UL" &&
      !hasPrecedingContent(val)
    ) {
      parent.classList.add("has-checkbox");
      val.classList.add("list-item-checkbox");
      if (!val.nextSibling) {
        val.insertAdjacentHTML("afterend", "&#8203;"); // Ensure otherwise empty <li> does not collapse height
      }
    }
  });
}

export function checklistSyntax(elem, postDecorator) {
  const boxes = [...elem.getElementsByClassName("chcklst-box")];
  addUlClasses(boxes);

  const postModel = postDecorator?.getModel();

  if (!postModel?.can_edit) {
    return;
  }

  boxes.forEach((box) => {
    box.onclick = async (event) => {
      const target = event.currentTarget;
      const classList = target.classList;

      if (classList.contains("permanent") || classList.contains("readonly")) {
        return;
      }

      const checkboxOffset = parseInt(target.dataset.chkOff, 10);
      if (isNaN(checkboxOffset)) {
        return;
      }

      const wasChecked = classList.contains("checked");

      // Optimistic UI update
      setCheckboxState(target, !wasChecked);
      boxes.forEach((b) => b.classList.add("readonly"));

      try {
        await ajax("/checklist/toggle", {
          type: "PUT",
          data: {
            post_id: postModel.id,
            checkbox_offset: checkboxOffset,
          },
        });
      } catch (e) {
        // Revert on failure
        setCheckboxState(target, wasChecked);
        popupAjaxError(e);
      } finally {
        boxes.forEach((b) => b.classList.remove("readonly"));
      }
    };
  });
}

export default {
  name: "checklist",

  initialize() {
    withPluginApi(initializePlugin);
  },
};
