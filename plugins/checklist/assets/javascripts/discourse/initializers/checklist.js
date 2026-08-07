import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import richEditorExtension from "../../lib/rich-editor-extension";

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

    api.addComposerToolbarPopupMenuOption({
      menu: "list",
      name: "list-checklist",
      icon: "list-check",
      label: "checklist.composer.checklist",
      showActiveIcon: true,
      active: ({ state }) => state?.inCheckList,
      action: (toolbarEvent) => {
        if (toolbarEvent.commands?.toggleChecklist) {
          toolbarEvent.commands.toggleChecklist();
        } else {
          toolbarEvent.applyList("- [ ] ", "list_item");
        }
      },
    });
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

  boxes.forEach((box, index) => {
    box.onclick = async (event) => {
      const target = event.currentTarget;
      const classList = target.classList;

      if (classList.contains("permanent") || classList.contains("readonly")) {
        return;
      }

      const wasChecked = classList.contains("checked");
      setCheckboxState(target, !wasChecked);

      const template = document.createElement("template");
      template.innerHTML = iconHTML("spinner", {
        class: "fa-spin list-item-checkbox",
      });
      const spinner = template.content.firstChild;
      target.insertAdjacentElement("afterend", spinner);
      target.classList.add("hidden");
      boxes.forEach((b) => b.classList.add("readonly"));

      try {
        await ajax("/checklist/toggle", {
          type: "PUT",
          data: {
            post_id: postModel.id,
            checkbox_index: index,
            checkbox_count: boxes.length,
            checked: !wasChecked,
          },
        });
      } catch (e) {
        setCheckboxState(target, wasChecked);
        popupAjaxError(e);
      } finally {
        spinner.remove();
        target.classList.remove("hidden");
        boxes.forEach((b) => b.classList.remove("readonly"));
      }
    };
  });
}

export default {
  name: "checklist",

  initialize() {
    withPluginApi((api) => initializePlugin(api));
  },
};
