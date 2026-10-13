import { cancel } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { registerOptimisticPostUpdate } from "discourse/lib/optimistic-post-updates";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import richEditorExtension from "../../lib/rich-editor-extension";

const SAVE_DEBOUNCE_DURATION = 150;
const MAX_CONFLICT_RETRIES = 2;
// Keep request batches within the toggle endpoint's contract.
const MAX_BATCH_SIZE = 50;
const REQUEST_TIMEOUT = 30000;

function timestampsAreEqual(first, second) {
  return Date.parse(first) === Date.parse(second);
}

function timestampIsOlder(candidate, reference) {
  return Date.parse(candidate) < Date.parse(reference);
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

function checkboxKey(box, renderedIndex, checkboxCount) {
  return box.dataset.chkSrc ?? `legacy:${renderedIndex}:${checkboxCount}`;
}

function checkboxTarget(box, renderedIndex, checkboxCount) {
  return {
    checkboxCount: box.dataset.chkSrc ? undefined : checkboxCount,
    checkboxSource: box.dataset.chkSrc,
    renderedIndex,
  };
}

function checklistFingerprint(raw, checkboxSources, includesLegacy) {
  if (typeof raw !== "string") {
    return;
  }

  if (includesLegacy) {
    return raw.replace(/\[(?: |x)?\]/g, "[ ]");
  }

  const sourcesByLine = new Map();
  checkboxSources.forEach((source) => {
    const [line, nth] = source.split(":").map(Number);
    if (!sourcesByLine.has(line)) {
      sourcesByLine.set(line, new Set());
    }
    sourcesByLine.get(line).add(nth);
  });

  const lines = raw.split(/\r\n?|\n/);
  let valid = true;
  sourcesByLine.forEach((indexes, lineNumber) => {
    if (lines[lineNumber] === undefined) {
      valid = false;
      return;
    }

    let markerIndex = -1;
    lines[lineNumber] = lines[lineNumber].replace(/\[[ xX]?\]/g, (marker) => {
      markerIndex += 1;
      return indexes.has(markerIndex) ? "[ ]" : marker;
    });
    if ([...indexes].some((index) => index > markerIndex)) {
      valid = false;
    }
  });
  return valid ? lines.join("\n") : undefined;
}

const activeChecklistOperations = new Map();
const uncertainChecklistBaseline = Symbol("uncertain-checklist-baseline");

function cookedChecklistFingerprint(cooked) {
  if (typeof cooked !== "string") {
    return;
  }
  const document = new DOMParser().parseFromString(cooked, "text/html");
  document.querySelectorAll(".chcklst-box:not(.permanent)").forEach((box) => {
    if (!isInsideSourcedQuote(box)) {
      box.classList.remove("checked", "fa-square-o", "fa-square-check-o");
    }
  });
  return document.body.innerHTML;
}

export function activeChecklistOperationCountForTesting() {
  return activeChecklistOperations.size;
}

function checklistRendering(postModel, boxes) {
  const mutableBoxes = boxes.filter(
    (box) => !box.classList.contains("permanent")
  );
  const checkboxSources = mutableBoxes
    .map((box) => box.dataset.chkSrc)
    .filter(Boolean);
  const includesLegacy = mutableBoxes.some((box) => !box.dataset.chkSrc);
  const fingerprintFor = (raw) =>
    checklistFingerprint(raw, checkboxSources, includesLegacy);
  const fingerprint = fingerprintFor(postModel.raw);
  const coverage = mutableBoxes
    .map((box) => box.dataset.chkSrc ?? "legacy")
    .join("\0");
  const generation =
    fingerprint === undefined
      ? `${postModel.updated_at ?? "unknown"}\0${mutableBoxes
          .map(
            (box) => `${box.dataset.chkSrc ?? "legacy"}:${checkboxLabel(box)}`
          )
          .join("\0")}`
      : `${fingerprint}\0${coverage}`;

  return {
    baselineUpdatedAt: postModel.updated_at,
    coverage,
    cookedFingerprint:
      fingerprint === undefined
        ? cookedChecklistFingerprint(postModel.cooked)
        : undefined,
    fingerprint,
    fingerprintFor,
    generation,
    invalid: false,
  };
}

function confirmChecklistPresentation(presentation, checked) {
  const { control, token } = presentation;
  if (control.state?.token === token) {
    control.state.confirmed = checked;
  }
}

function setChecklistPending(control, pending) {
  control.box?.classList.toggle("is-pending", pending);
  if (pending) {
    control.box?.setAttribute("aria-busy", "true");
  } else {
    control.box?.removeAttribute("aria-busy");
  }
}

function settleChecklistPresentation(presentation, checked) {
  const { control, token } = presentation;
  if (control.state?.token !== token) {
    return;
  }

  control.state = undefined;
  if (control.box) {
    setCheckboxState(control.box, checked);
  }
  setChecklistPending(control, false);
}

function enqueueChecklistChange(change) {
  const postId = change.postModel.id;
  if (postId == null) {
    settleChecklistPresentation(
      { control: change.control, token: change.token },
      change.confirmed
    );
    return;
  }

  let operation = activeChecklistOperations.get(postId);
  if (!operation) {
    operation = new ChecklistOperation(change.postModel);
    activeChecklistOperations.set(postId, operation);
  }
  operation.enqueue(change);
}

function bindChecklist(boxes, postModel) {
  const rendering = checklistRendering(postModel, boxes);
  const abortController = new AbortController();
  const controls = [];

  boxes.forEach((box, renderedIndex) => {
    if (box.classList.contains("permanent")) {
      return;
    }

    const control = {
      box,
      key: checkboxKey(box, renderedIndex, boxes.length),
      rendering,
      state: undefined,
      target: checkboxTarget(box, renderedIndex, boxes.length),
    };
    controls.push(control);

    const activate = (event) => {
      if (
        event.type === "keydown" &&
        event.key !== " " &&
        event.key !== "Enter"
      ) {
        return;
      }

      event.preventDefault();
      if (event.repeat || rendering.invalid) {
        return;
      }

      const checked = !control.box.classList.contains("checked");
      const token = Symbol();
      const confirmed = control.state?.confirmed ?? !checked;
      control.state = { confirmed, token };
      setCheckboxState(control.box, checked);
      setChecklistPending(control, true);
      enqueueChecklistChange({
        checked,
        confirmed,
        control,
        key: control.key,
        postModel,
        rendering,
        target: control.target,
        token,
      });
    };

    box.addEventListener("click", activate, {
      signal: abortController.signal,
    });
    box.addEventListener("keydown", activate, {
      signal: abortController.signal,
    });
    activeChecklistOperations.get(postModel.id)?.adopt(control);
  });

  return () => {
    abortController.abort();
    controls.forEach((control) => {
      setChecklistPending(control, false);
      control.box = undefined;
      control.state = undefined;
    });
  };
}

class ChecklistOperation {
  #baselineRaw;
  #baselineUpdatedAt;
  #intents = new Map();
  #inFlight = new Set();
  #hydratedGenerations = new Map();
  #postModel;
  #revision = 0;
  #saveTimer;
  #saving = false;

  constructor(postModel) {
    this.#postModel = postModel;
    this.#baselineRaw = postModel[uncertainChecklistBaseline]
      ? undefined
      : postModel.raw;
    this.#baselineUpdatedAt = postModel.updated_at;
  }

  adopt(control) {
    this.#resolveGeneration(control.rendering);
    const intent = this.#intents.get(
      `${control.rendering.generation}\0${control.key}`
    );
    if (!intent) {
      return;
    }

    const token = Symbol();
    control.state = { confirmed: intent.confirmed, token };
    setCheckboxState(control.box, intent.checked);
    setChecklistPending(control, true);
    intent.presentations = intent.presentations.filter(
      (presentation) =>
        presentation.control.box && presentation.control !== control
    );
    intent.presentations.push({ control, token });
  }

  enqueue(change) {
    this.#observePostModel(change.postModel);
    this.#resolveGeneration(change.rendering);

    const intentKey = `${change.rendering.generation}\0${change.key}`;
    const previous = this.#intents.get(intentKey);
    const presentations = (previous?.presentations ?? []).filter(
      (presentation) =>
        presentation.control.box && presentation.control !== change.control
    );
    presentations.push({ control: change.control, token: change.token });
    const confirmed = previous?.confirmed ?? change.confirmed;
    if (
      (!this.#saving ||
        (this.#inFlight.size > 0 && !this.#inFlight.has(intentKey))) &&
      change.checked === confirmed
    ) {
      this.#intents.delete(intentKey);
      presentations.forEach((presentation) =>
        settleChecklistPresentation(presentation, confirmed)
      );
      this.#retireIfDrained();
      return;
    }

    this.#intents.set(intentKey, {
      checked: change.checked,
      confirmed,
      fingerprint: previous?.fingerprint ?? change.rendering.fingerprint,
      presentations,
      rendering: previous?.rendering ?? change.rendering,
      revision: (this.#revision += 1),
      target: change.target,
    });

    if (!this.#saving) {
      this.#saveTimer = discourseDebounce(
        this,
        this.#save,
        SAVE_DEBOUNCE_DURATION
      );
    }
  }

  #applyBaseline(raw, updatedAt) {
    this.#baselineRaw = raw;
    this.#baselineUpdatedAt = updatedAt;
  }

  #completeBatch(entries) {
    entries.forEach(([key, saved]) => {
      const current = this.#intents.get(key);
      if (!current) {
        return;
      }

      if (
        current.checked === saved.checked &&
        current.fingerprint === saved.fingerprint
      ) {
        this.#intents.delete(key);
        current.presentations.forEach((presentation) =>
          settleChecklistPresentation(presentation, saved.checked)
        );
      } else {
        current.confirmed = saved.checked;
        current.presentations.forEach((presentation) =>
          confirmChecklistPresentation(presentation, saved.checked)
        );
      }
    });
  }

  #currentEntries(entries) {
    return entries.filter(
      ([key, saved]) => this.#intents.get(key)?.checked === saved.checked
    );
  }

  #entriesForNextGeneration() {
    const first = this.#intents.values().next().value;
    return [...this.#intents]
      .filter(
        ([, intent]) =>
          intent.rendering.generation === first.rendering.generation
      )
      .slice(0, MAX_BATCH_SIZE);
  }

  #failBatch(entries) {
    entries.forEach(([key, failed]) => {
      const current = this.#intents.get(key);
      if (current?.revision !== failed.revision) {
        return;
      }

      this.#intents.delete(key);
      current.presentations.forEach((presentation) =>
        settleChecklistPresentation(presentation, current.confirmed)
      );
    });
  }

  #failGeneration(generation, invalidate = false) {
    const entries = [...this.#intents].filter(
      ([, intent]) => intent.rendering.generation === generation
    );
    if (invalidate) {
      entries.forEach(([, intent]) => {
        intent.rendering.invalid = true;
        intent.presentations.forEach((presentation) => {
          presentation.control.rendering.invalid = true;
          if (presentation.control.box) {
            configureAccessibility(presentation.control.box, false);
          }
        });
      });
    }
    this.#failBatch(entries);
  }

  #freshestBaseline(raw, updatedAt) {
    if (
      this.#postModel.raw != null &&
      (timestampIsOlder(updatedAt, this.#postModel.updated_at) ||
        (timestampsAreEqual(updatedAt, this.#postModel.updated_at) &&
          raw !== this.#postModel.raw))
    ) {
      return {
        raw: this.#postModel.raw,
        updatedAt: this.#postModel.updated_at,
      };
    }

    return { raw, updatedAt };
  }

  async #hydrate(entries) {
    if (
      this.#baselineRaw != null &&
      entries.every(([, intent]) => intent.fingerprint !== undefined)
    ) {
      return true;
    }

    const rendering = entries[0][1].rendering;
    try {
      const post = await ajax(`/posts/${this.#postModel.id}`, {
        timeout: REQUEST_TIMEOUT,
        ignoreUnsent: false,
      });
      const baseline = this.#postModel[uncertainChecklistBaseline]
        ? { raw: post.raw, updatedAt: post.updated_at }
        : this.#freshestBaseline(post.raw, post.updated_at);
      const fingerprint = rendering.fingerprintFor(baseline.raw);
      const canUseBaseline = entries.every(([, intent]) => {
        return (
          timestampsAreEqual(
            intent.rendering.baselineUpdatedAt,
            baseline.updatedAt
          ) ||
          (intent.fingerprint !== undefined &&
            intent.rendering.fingerprintFor(baseline.raw) ===
              intent.fingerprint) ||
          (intent.rendering.cookedFingerprint !== undefined &&
            intent.rendering.cookedFingerprint ===
              cookedChecklistFingerprint(post.cooked))
        );
      });
      if (!canUseBaseline || fingerprint === undefined) {
        this.#failGeneration(rendering.generation, true);
        this.#refreshPost(true);
        return false;
      }

      const oldGeneration = rendering.generation;
      const resolved = {
        fingerprint,
        generation: `${fingerprint}\0${rendering.coverage}`,
      };
      this.#hydratedGenerations.set(oldGeneration, resolved);
      for (const [key, intent] of [...this.#intents]) {
        if (
          intent.rendering.generation !== oldGeneration &&
          !key.startsWith(`${oldGeneration}\0`)
        ) {
          continue;
        }
        this.#resolveGeneration(intent.rendering);
        intent.fingerprint = fingerprint;
        intent.presentations.forEach(({ control }) =>
          this.#resolveGeneration(control.rendering)
        );
        const newKey = `${resolved.generation}${key.slice(oldGeneration.length)}`;
        const existing = this.#intents.get(newKey);
        let merged = intent;
        if (existing && existing !== intent) {
          const latest =
            existing.revision > intent.revision ? existing : intent;
          merged = {
            ...latest,
            presentations: [
              ...existing.presentations,
              ...intent.presentations,
            ].filter(
              ({ control, token }) =>
                control.box && control.state?.token === token
            ),
          };
        }
        this.#intents.delete(key);
        this.#intents.set(newKey, merged);
        entries.forEach((entry) => {
          if (entry[0] === key) {
            entry[0] = newKey;
            entry[1].fingerprint = fingerprint;
            if (existing && existing !== intent) {
              entry[1] = merged;
            }
          }
        });
      }
      this.#applyBaseline(baseline.raw, baseline.updatedAt);
      delete this.#postModel[uncertainChecklistBaseline];
      if (this.#postModel.raw == null) {
        this.#postModel.raw = baseline.raw;
      }
      return true;
    } catch (error) {
      this.#postModel[uncertainChecklistBaseline] = true;
      this.#failGeneration(rendering.generation);
      popupAjaxError(error);
      return false;
    }
  }

  #observePostModel(postModel) {
    if (
      this.#postModel.raw == null ||
      timestampIsOlder(this.#postModel.updated_at, postModel.updated_at) ||
      (Number.isFinite(postModel.version) &&
        Number.isFinite(this.#postModel.version) &&
        postModel.version > this.#postModel.version)
    ) {
      this.#postModel = postModel;
    }
  }

  #refreshPost(reportError = false) {
    const refresh = this.#postModel.topic?.postStream?.refreshPost(
      this.#postModel.id
    );
    if (refresh) {
      void refresh.catch(reportError ? popupAjaxError : () => {});
    }
  }

  #resolveGeneration(rendering) {
    const resolved = this.#hydratedGenerations.get(rendering.generation);
    if (resolved) {
      Object.assign(rendering, resolved);
    }
  }

  #retireIfDrained() {
    if (this.#saving || this.#intents.size > 0) {
      return;
    }

    if (this.#saveTimer) {
      cancel(this.#saveTimer);
      this.#saveTimer = undefined;
    }
    if (activeChecklistOperations.get(this.#postModel.id) === this) {
      activeChecklistOperations.delete(this.#postModel.id);
    }
  }

  async #save() {
    this.#saveTimer = undefined;
    if (this.#saving) {
      return;
    }

    this.#saving = true;
    try {
      while (this.#intents.size > 0) {
        let entries = this.#entriesForNextGeneration();
        let retries = 0;

        while ((entries = this.#currentEntries(entries)).length > 0) {
          if (!(await this.#hydrate(entries))) {
            break;
          }
          entries = this.#currentEntries(entries);
          if (entries.length === 0) {
            break;
          }

          if (
            this.#postModel.raw != null &&
            timestampIsOlder(
              this.#baselineUpdatedAt,
              this.#postModel.updated_at
            )
          ) {
            this.#applyBaseline(
              this.#postModel.raw,
              this.#postModel.updated_at
            );
          }

          const rendering = entries[0][1].rendering;
          const fingerprint = entries[0][1].fingerprint;
          const baselineFingerprint = rendering.fingerprintFor(
            this.#baselineRaw
          );
          const modelFingerprint = rendering.fingerprintFor(
            this.#postModel.raw
          );
          if (
            fingerprint === undefined ||
            baselineFingerprint === undefined ||
            fingerprint !== baselineFingerprint ||
            (this.#postModel.raw != null && fingerprint !== modelFingerprint)
          ) {
            this.#failGeneration(rendering.generation, true);
            this.#refreshPost(true);
            break;
          }

          const mutationId = crypto.randomUUID();
          const {
            startExpiration: startOptimisticUpdateExpiration,
            unregister: unregisterOptimisticUpdate,
          } = registerOptimisticPostUpdate(mutationId);
          const data = {
            post_id: this.#postModel.id,
            toggles: entries.map(([, intent]) => {
              const toggle = {
                checkbox_index: intent.target.renderedIndex,
                checkbox_source: intent.target.checkboxSource,
                checked: intent.checked,
              };
              if (!intent.target.checkboxSource) {
                toggle.checkbox_count = intent.target.checkboxCount;
              }
              return toggle;
            }),
            expected_raw: this.#baselineRaw,
            expected_updated_at: this.#baselineUpdatedAt,
            mutation_id: mutationId,
          };

          try {
            this.#inFlight = new Set(entries.map(([key]) => key));
            const response = await ajax("/checklist/toggle", {
              type: "PUT",
              timeout: REQUEST_TIMEOUT,
              ignoreUnsent: false,
              contentType: "application/json",
              data: JSON.stringify(data),
            });
            const stale =
              (Number.isFinite(response.version) &&
                Number.isFinite(this.#postModel.version) &&
                response.version < this.#postModel.version) ||
              timestampIsOlder(response.updated_at, this.#postModel.updated_at);

            if (response.revised) {
              startOptimisticUpdateExpiration();
            } else {
              unregisterOptimisticUpdate();
            }

            if (stale) {
              if (response.raw === this.#postModel.raw) {
                this.#completeBatch(entries);
                this.#applyBaseline(
                  this.#postModel.raw,
                  this.#postModel.updated_at
                );
                break;
              }

              const baseline = this.#freshestBaseline(
                response.raw,
                response.updated_at
              );
              const canRetry =
                retries < MAX_CONFLICT_RETRIES &&
                rendering.fingerprintFor(baseline.raw) === fingerprint;
              this.#applyBaseline(baseline.raw, baseline.updatedAt);
              if (canRetry) {
                retries += 1;
                continue;
              }

              this.#failBatch(entries);
              this.#refreshPost();
              break;
            }

            if (rendering.fingerprintFor(this.#postModel.raw) !== fingerprint) {
              this.#applyBaseline(
                this.#postModel.raw,
                this.#postModel.updated_at
              );
              this.#failGeneration(rendering.generation, true);
              this.#refreshPost();
              break;
            }

            this.#postModel.last_editor_id = response.last_editor_id;
            this.#postModel.updated_at = response.updated_at;
            this.#postModel.version = response.version;
            this.#postModel.raw = response.raw;
            this.#applyBaseline(response.raw, response.updated_at);
            this.#completeBatch(entries);
            this.#postModel.cooked = response.cooked;
            break;
          } catch (error) {
            unregisterOptimisticUpdate();
            const conflict = error.jqXHR?.responseJSON;
            const baseline =
              conflict?.raw && conflict?.updated_at
                ? this.#freshestBaseline(conflict.raw, conflict.updated_at)
                : undefined;
            const canRetry =
              error.jqXHR?.status === 409 &&
              conflict?.retryable &&
              baseline &&
              retries < MAX_CONFLICT_RETRIES &&
              rendering.fingerprintFor(baseline.raw) === fingerprint;

            if (canRetry) {
              this.#applyBaseline(baseline.raw, baseline.updatedAt);
              retries += 1;
              continue;
            }

            const structuralConflict =
              error.jqXHR?.status === 409 &&
              baseline &&
              rendering.fingerprintFor(baseline.raw) !== fingerprint;
            if (structuralConflict) {
              this.#failGeneration(rendering.generation, true);
            } else {
              this.#failBatch(entries);
            }
            if (baseline) {
              this.#applyBaseline(baseline.raw, baseline.updatedAt);
            } else if (!error.jqXHR || error.jqXHR.status === 0) {
              this.#baselineRaw = undefined;
              this.#postModel[uncertainChecklistBaseline] = true;
            } else if (this.#postModel.raw != null) {
              this.#applyBaseline(
                this.#postModel.raw,
                this.#postModel.updated_at
              );
            }
            this.#refreshPost();
            popupAjaxError(error);
            break;
          } finally {
            this.#inFlight.clear();
          }
        }
      }
    } catch (error) {
      this.#failBatch([...this.#intents]);
      popupAjaxError(error);
    } finally {
      this.#saving = false;
      this.#retireIfDrained();
    }
  }
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

  if (editable && interactiveBoxes.length > 0) {
    return bindChecklist(interactiveBoxes, postModel);
  }
}

export default {
  name: "checklist",

  initialize() {
    withPluginApi((api) => initializePlugin(api));
  },
};
