import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import richEditorExtension from "../../lib/rich-editor-extension";
import { A } from "@ember/array";

function setCheckboxState(checkbox, checked) {
  checkbox.classList.toggle("checked", checked);
  checkbox.classList.toggle("fa-square-o", !checked);
  checkbox.classList.toggle("fa-square-check-o", checked);
}

function initializePlugin(api) {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings.checklist_enabled) {
    api.decorateCookedElement(checklistSyntax);
    api.registerRichEditorExtension(richEditorExtension);

    api.modifyClass(
      "controller:topic",
      (Superclass) =>
        class extends Superclass {
          onChecklistMessage({ post_id, checkbox_offset, checked }) {
            const postArticle = document.querySelector(
              `article[data-post-id="${post_id}"]`
            );

            if (!postArticle) {
              return;
            }

            const checkbox = postArticle.querySelector(
              `.chcklst-box[data-chk-off="${checkbox_offset}"]`
            );

            if (checkbox) {
              setCheckboxState(checkbox, checked);
              checkbox.classList.remove("hidden");
              checkbox.nextElementSibling?.remove(); // remove spinner
            }

            // Remove readonly from all checkboxes in this post
            postArticle
              .querySelectorAll(".chcklst-box.readonly")
              .forEach((box) => box.classList.remove("readonly"));
          }

          subscribe() {
            super.subscribe(...arguments);
            this.messageBus.subscribe(
              `/checklist/${this.model.id}`,
              this.onChecklistMessage
            );
          }

          unsubscribe() {
            super.unsubscribe(...arguments);
            this.messageBus.unsubscribe(
              `/checklist/${this.model.id}`,
              this.onChecklistMessage
            );
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
        val.insertAdjacentHTML("afterend", "&#8203;");
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
      setCheckboxState(target, !wasChecked);

      const spinner = document.createElement("span");
      spinner.innerHTML = iconHTML("spinner", { class: "fa-spin" });
      target.insertAdjacentElement("afterend", spinner);
      target.classList.add("hidden");
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
        setCheckboxState(target, wasChecked);
        spinner.remove();
        target.classList.remove("hidden");
        boxes.forEach((b) => b.classList.remove("readonly"));
        popupAjaxError(e);
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
