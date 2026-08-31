import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { iconHTML } from "discourse/lib/icon-library";
import { registerOptimisticPostUpdate } from "discourse/lib/optimistic-post-updates";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import richEditorExtension from "../../lib/rich-editor-extension";

const MINIMUM_SPINNER_DURATION = 200;
const MAX_CONFLICT_RETRIES = 2;

function timestampIsOlder(candidate, reference) {
  const candidateTime = Date.parse(candidate);
  const referenceTime = Date.parse(reference);
  return (
    !Number.isNaN(candidateTime) &&
    !Number.isNaN(referenceTime) &&
    candidateTime < referenceTime
  );
}

function setCheckboxState(checkbox, checked) {
  checkbox.classList.toggle("checked", checked);
  checkbox.classList.toggle("fa-square-o", !checked);
  checkbox.classList.toggle("fa-square-check-o", checked);
  checkbox.setAttribute("aria-checked", checked.toString());
}

function checkboxLabel(checkbox) {
  const parts = [];
  let sibling = checkbox.nextSibling;

  while (sibling) {
    if (
      sibling.nodeType === Node.ELEMENT_NODE &&
      (sibling.classList.contains("chcklst-box") ||
        sibling.querySelector(".chcklst-box"))
    ) {
      break;
    }

    parts.push(sibling.textContent);
    sibling = sibling.nextSibling;
  }

  const label = parts.join("").replaceAll("\u200b", "").trim();
  return label.slice(0, 200) || i18n("checklist.item");
}

function initializePlugin(api) {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings.checklist_enabled) {
    api.decorateCookedElement(checklistSyntax, { onlyStream: true });
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
  boxes.forEach((box) => {
    let parent = box.parentElement;
    if (
      parent.nodeName === "P" &&
      parent.parentElement.firstElementChild === parent
    ) {
      parent = parent.parentElement;
    }

    if (
      parent.nodeName === "LI" &&
      parent.parentElement.nodeName === "UL" &&
      !hasPrecedingContent(box)
    ) {
      parent.classList.add("has-checkbox");
      box.classList.add("list-item-checkbox");
      if (!box.nextSibling) {
        // Prevent an otherwise empty list item from collapsing.
        box.insertAdjacentHTML("afterend", "&#8203;");
      }
    }
  });
}

function configureAccessibility(box, editable) {
  const checked = box.classList.contains("checked");
  const permanent = box.classList.contains("permanent");

  box.classList.toggle("is-interactive", editable && !permanent);
  box.setAttribute("role", "checkbox");
  box.setAttribute("aria-checked", checked.toString());
  box.setAttribute("aria-label", checkboxLabel(box));
  box.removeAttribute("aria-disabled");
  box.removeAttribute("aria-readonly");
  box.removeAttribute("tabindex");

  if (permanent) {
    box.setAttribute("aria-disabled", "true");
  } else if (editable) {
    box.setAttribute("tabindex", "0");
  } else {
    box.setAttribute("aria-readonly", "true");
  }
}

function addToggleBehavior(boxes, postModel, allBoxes = boxes) {
  const renderedIndexes = new Map(allBoxes.map((box, index) => [box, index]));
  const confirmedStates = boxes.map((box) => box.classList.contains("checked"));
  const pendingStates = new Map();
  const spinnerStates = new Map();
  const cleanups = [];
  let expectedRaw = postModel.raw;
  let expectedUpdatedAt = postModel.updated_at;
  let active = true;
  let deferredCooked;
  let saving = false;
  let unregisterInFlightOptimisticUpdate;

  const stopSpinner = (index) => {
    clearTimeout(spinnerStates.get(index)?.timer);
    spinnerStates.delete(index);
    boxes[index].classList.remove("is-saving");
    boxes[index].removeAttribute("aria-disabled");
  };

  const updateBusyState = (index, busy) => {
    const box = boxes[index];

    if (busy) {
      clearTimeout(spinnerStates.get(index)?.timer);
      if (!box.querySelector(".checklist-spinner")) {
        box.insertAdjacentHTML(
          "beforeend",
          iconHTML("spinner", { class: "checklist-spinner" })
        );
      }
      spinnerStates.set(index, { startedAt: performance.now() });
      box.classList.add("is-saving");
      box.setAttribute("aria-busy", "true");
      box.setAttribute("aria-disabled", "true");
      return;
    }

    box.removeAttribute("aria-busy");
    const spinnerState = spinnerStates.get(index);
    if (!spinnerState) {
      box.classList.remove("is-saving");
      return;
    }

    clearTimeout(spinnerState.timer);
    const elapsed = performance.now() - spinnerState.startedAt;
    const remaining = Math.max(0, MINIMUM_SPINNER_DURATION - elapsed);

    if (remaining === 0) {
      stopSpinner(index);
    } else {
      spinnerState.timer = setTimeout(() => stopSpinner(index), remaining);
    }
  };

  const restoreConfirmedStates = () => {
    boxes.forEach((box, index) => {
      setCheckboxState(box, confirmedStates[index]);
      updateBusyState(index, false);
    });
  };

  const savePendingStates = async () => {
    if (saving) {
      return;
    }

    saving = true;
    let retryBatch;

    try {
      while (active && (retryBatch || pendingStates.size > 0)) {
        const batch = retryBatch ?? {
          states: [...pendingStates],
          conflictRetries: 0,
        };
        retryBatch = undefined;
        batch.states.forEach(([index, state]) => {
          if (pendingStates.get(index) === state) {
            pendingStates.delete(index);
          }
        });

        if (expectedRaw == null) {
          try {
            const post = await ajax(`/posts/${postModel.id}`);
            expectedRaw = post.raw;
            expectedUpdatedAt = post.updated_at;
          } catch (error) {
            pendingStates.clear();
            restoreConfirmedStates();
            popupAjaxError(error);
            break;
          }

          if (!active) {
            break;
          }
        }

        const mutationId = crypto.randomUUID();
        const {
          startExpiration: startOptimisticUpdateExpiration,
          unregister: unregisterOptimisticUpdate,
        } = registerOptimisticPostUpdate(mutationId);
        unregisterInFlightOptimisticUpdate = unregisterOptimisticUpdate;
        const toggles = batch.states.map(([index, checked]) => {
          const checkboxSource = boxes[index].dataset.chkSrc;
          const toggle = {
            checkbox_index: renderedIndexes.get(boxes[index]),
            checkbox_source: checkboxSource,
            checked,
          };
          if (!checkboxSource) {
            toggle.checkbox_count = allBoxes.length;
          }
          return toggle;
        });
        const data = {
          post_id: postModel.id,
          toggles,
          expected_raw: expectedRaw,
          expected_updated_at: expectedUpdatedAt,
          mutation_id: mutationId,
        };

        try {
          const response = await ajax("/checklist/toggle", {
            type: "PUT",
            contentType: "application/json",
            data: JSON.stringify(data),
          });
          const responseIsStale = timestampIsOlder(
            response.updated_at,
            postModel.updated_at
          );
          if (!responseIsStale) {
            postModel.last_editor_id = response.last_editor_id;
            postModel.updated_at = response.updated_at;
            postModel.version = response.version;
          }

          if (response.revised) {
            startOptimisticUpdateExpiration();
          } else {
            unregisterOptimisticUpdate();
          }
          unregisterInFlightOptimisticUpdate = undefined;

          if (!responseIsStale && (!active || pendingStates.size === 0)) {
            postModel.raw = response.raw;
            if (active) {
              deferredCooked = {
                cooked: response.cooked,
                updatedAt: response.updated_at,
              };
            } else {
              postModel.cooked = response.cooked;
            }
          }

          if (!active) {
            break;
          }

          batch.states.forEach(([index, desiredState]) => {
            confirmedStates[index] = desiredState;
            if (pendingStates.get(index) === desiredState) {
              pendingStates.delete(index);
            }
          });
          expectedRaw = response.raw;
          expectedUpdatedAt = response.updated_at;
        } catch (error) {
          unregisterInFlightOptimisticUpdate = undefined;
          unregisterOptimisticUpdate();

          if (!active) {
            break;
          }

          const conflict = error.jqXHR?.responseJSON;
          if (
            error.jqXHR?.status === 409 &&
            conflict?.retryable &&
            conflict.raw &&
            conflict.updated_at &&
            batch.conflictRetries < MAX_CONFLICT_RETRIES
          ) {
            expectedRaw = conflict.raw;
            expectedUpdatedAt = conflict.updated_at;
            if (!timestampIsOlder(conflict.updated_at, postModel.updated_at)) {
              postModel.updated_at = conflict.updated_at;
            }
            retryBatch = {
              states: batch.states,
              conflictRetries: batch.conflictRetries + 1,
            };
            continue;
          }

          pendingStates.clear();
          restoreConfirmedStates();
          const postStream = postModel.topic?.postStream;
          if (postStream) {
            void postStream.refreshPost(postModel.id).catch(() => {});
          }
          popupAjaxError(error);
          break;
        } finally {
          if (active) {
            const retryingIndexes = new Set(
              retryBatch?.states.map(([index]) => index)
            );
            for (const [index] of batch.states) {
              if (!retryingIndexes.has(index) && !pendingStates.has(index)) {
                updateBusyState(index, false);
              }
            }
          }
        }
      }
    } finally {
      saving = false;
    }
  };

  boxes.forEach((box, index) => {
    if (box.classList.contains("permanent")) {
      return;
    }

    const toggle = () => {
      if (box.classList.contains("is-saving")) {
        return;
      }

      const desiredState = !box.classList.contains("checked");
      setCheckboxState(box, desiredState);
      pendingStates.set(index, desiredState);
      updateBusyState(index, true);
      void savePendingStates();
    };

    const onClick = (event) => {
      event.preventDefault();
      toggle();
    };

    const onKeyDown = (event) => {
      if (event.key !== " " && event.key !== "Enter") {
        return;
      }

      event.preventDefault();
      toggle();
    };

    box.addEventListener("click", onClick);
    box.addEventListener("keydown", onKeyDown);
    cleanups.push(() => {
      box.removeEventListener("click", onClick);
      box.removeEventListener("keydown", onKeyDown);
    });
  });

  return () => {
    active = false;
    pendingStates.clear();
    unregisterInFlightOptimisticUpdate?.();
    unregisterInFlightOptimisticUpdate = undefined;
    spinnerStates.forEach(({ timer }) => clearTimeout(timer));
    boxes.forEach((box) => {
      box.classList.remove("is-saving");
      box.removeAttribute("aria-busy");
      if (box.classList.contains("is-interactive")) {
        box.removeAttribute("aria-disabled");
      }
    });
    cleanups.forEach((cleanup) => cleanup());

    const cookedUpdate = deferredCooked;
    deferredCooked = undefined;
    if (cookedUpdate) {
      schedule("afterRender", () => {
        if (!timestampIsOlder(cookedUpdate.updatedAt, postModel.updated_at)) {
          postModel.cooked = cookedUpdate.cooked;
        }
      });
    }
  };
}

function isInsideSourcedQuote(box) {
  return Boolean(
    box.closest(
      "aside.quote[data-username], aside.quote[data-post], aside.quote[data-topic]"
    )
  );
}

export function checklistSyntax(elem, postDecorator) {
  const boxes = [...elem.getElementsByClassName("chcklst-box")];
  addUlClasses(boxes);

  const postModel = postDecorator?.getModel();
  const editable = postModel?.can_edit === true;
  const interactiveBoxes = boxes.filter((box) => !isInsideSourcedQuote(box));
  const interactiveBoxSet = new Set(interactiveBoxes);

  boxes.forEach((box) =>
    configureAccessibility(box, editable && interactiveBoxSet.has(box))
  );

  if (editable) {
    return addToggleBehavior(interactiveBoxes, postModel);
  }
}

export default {
  name: "checklist",

  initialize() {
    withPluginApi((api) => initializePlugin(api));
  },
};
