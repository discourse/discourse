import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { registerOptimisticPostUpdate } from "discourse/lib/optimistic-post-updates";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import richEditorExtension from "../../lib/rich-editor-extension";

const MINIMUM_PENDING_DURATION = 200;
const MAX_CONFLICT_RETRIES = 2;

function timestampsAreEqual(first, second) {
  const firstTime = Date.parse(first);
  const secondTime = Date.parse(second);
  return (
    !Number.isNaN(firstTime) &&
    !Number.isNaN(secondTime) &&
    firstTime === secondTime
  );
}

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

const checklistStates = new WeakMap();

function checkboxKey(renderedIndex, checkboxCount) {
  return `${renderedIndex}:${checkboxCount}`;
}

function checkboxTarget(box, renderedIndex, checkboxCount) {
  return {
    checkboxCount: box.dataset.chkSrc ? undefined : checkboxCount,
    checkboxSource: box.dataset.chkSrc,
    renderedIndex,
  };
}

function checklistBindingSignature(boxes) {
  return boxes
    .filter((box) => !box.classList.contains("permanent"))
    .map((box) => `${box.dataset.chkSrc ?? "legacy"}:${checkboxLabel(box)}`)
    .join("\0");
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

  const lines = raw.split("\n");
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

class ChecklistState {
  #baselineRaw;
  #baselineUpdatedAt;
  #binding;
  #bindingSignature;
  #checkboxSources = [];
  #fingerprint;
  #includesLegacy = false;
  #indicators = new Map();
  #intents = new Map();
  #postModel;
  #revision = 0;
  #saving = false;

  constructor(postModel) {
    this.#postModel = postModel;
    this.#baselineRaw = postModel.raw;
    this.#baselineUpdatedAt = postModel.updated_at;
  }

  bind(boxes, allBoxes = boxes) {
    this.#binding?.cleanup();

    const renderedIndexes = new Map(allBoxes.map((box, index) => [box, index]));
    const mutableBoxes = allBoxes.filter(
      (box) => !box.classList.contains("permanent")
    );
    const bindingSignature = checklistBindingSignature(allBoxes);
    const checkboxSources = mutableBoxes
      .map((box) => box.dataset.chkSrc)
      .filter(Boolean);
    const includesLegacy = mutableBoxes.some((box) => !box.dataset.chkSrc);
    const raw = this.#postModel.raw ?? this.#baselineRaw;
    const fingerprint = checklistFingerprint(
      raw,
      checkboxSources,
      includesLegacy
    );

    if (
      (this.#fingerprint !== undefined &&
        fingerprint !== undefined &&
        this.#fingerprint !== fingerprint) ||
      (this.#intents.size > 0 &&
        fingerprint === undefined &&
        this.#bindingSignature !== undefined &&
        this.#bindingSignature !== bindingSignature)
    ) {
      this.#discardIntents();
    }

    this.#bindingSignature = bindingSignature;
    this.#checkboxSources = checkboxSources;
    this.#includesLegacy = includesLegacy;
    if (fingerprint !== undefined || this.#intents.size === 0) {
      this.#fingerprint = fingerprint;
    }

    if (
      !this.#saving &&
      this.#intents.size === 0 &&
      this.#postModel.raw != null &&
      !timestampIsOlder(this.#postModel.updated_at, this.#baselineUpdatedAt)
    ) {
      this.#baselineRaw = this.#postModel.raw;
      this.#baselineUpdatedAt = this.#postModel.updated_at;
    }

    const binding = {
      cleaned: false,
      cleanup: undefined,
      cleanups: [],
      controls: new Map(),
    };

    boxes.forEach((box) => {
      if (box.classList.contains("permanent")) {
        return;
      }

      const renderedIndex = renderedIndexes.get(box);
      const key = checkboxKey(renderedIndex, allBoxes.length);
      const target = checkboxTarget(box, renderedIndex, allBoxes.length);
      binding.controls.set(key, box);

      const toggle = () => {
        const checked = !box.classList.contains("checked");
        const previous = this.#intents.get(key);
        this.#intents.set(key, {
          checked,
          confirmed: previous?.confirmed ?? !checked,
          fingerprint: this.#fingerprint,
          revision: (this.#revision += 1),
          target,
        });
        setCheckboxState(box, checked);
        this.#startIndicator(key);
        void this.#save();
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
      binding.cleanups.push(() => {
        box.removeEventListener("click", onClick);
        box.removeEventListener("keydown", onKeyDown);
      });
    });

    for (const key of this.#intents.keys()) {
      if (!binding.controls.has(key)) {
        this.#discardIntent(key);
      }
    }

    this.#binding = binding;
    binding.controls.forEach((box, key) => this.#syncControl(key, box));

    binding.cleanup = () => {
      if (binding.cleaned) {
        return;
      }

      binding.cleaned = true;
      binding.cleanups.forEach((cleanup) => cleanup());
      binding.controls.forEach((box) => {
        box.classList.remove("is-pending");
        box.removeAttribute("aria-busy");
      });
      if (this.#binding === binding) {
        this.#binding = undefined;
      }
    };
    return binding.cleanup;
  }

  #applyBaseline(raw, updatedAt) {
    this.#baselineRaw = raw;
    this.#baselineUpdatedAt = updatedAt;
  }

  #clearIndicator(key, indicator = this.#indicators.get(key)) {
    if (!indicator || this.#indicators.get(key) !== indicator) {
      return;
    }

    clearTimeout(indicator.timer);
    this.#indicators.delete(key);
    const box = this.#binding?.controls.get(key);
    box?.classList.remove("is-pending");
    box?.removeAttribute("aria-busy");
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
        this.#finishIndicator(key);
      } else {
        current.confirmed = saved.checked;
      }
    });
  }

  #currentEntries(entries) {
    return entries
      .map(([key, saved]) => {
        const current = this.#intents.get(key);
        return current?.checked === saved.checked ? [key, saved] : undefined;
      })
      .filter(Boolean);
  }

  #discardIntent(key) {
    this.#intents.delete(key);
    this.#clearIndicator(key);
  }

  #discardIntents() {
    const keys = [...this.#intents.keys()];
    this.#intents.clear();
    keys.forEach((key) => this.#clearIndicator(key));
  }

  #failBatch(entries) {
    entries.forEach(([key, failed]) => {
      const current = this.#intents.get(key);
      if (current?.revision !== failed.revision) {
        return;
      }

      this.#intents.delete(key);
      const box = this.#binding?.controls.get(key);
      if (box) {
        setCheckboxState(box, failed.confirmed);
      }
      this.#finishIndicator(key);
    });
  }

  #finishIndicator(key) {
    const indicator = this.#indicators.get(key);
    const box = this.#binding?.controls.get(key);
    box?.removeAttribute("aria-busy");
    if (!indicator) {
      box?.classList.remove("is-pending");
      return;
    }

    clearTimeout(indicator.timer);
    const remaining = Math.max(
      0,
      MINIMUM_PENDING_DURATION - (performance.now() - indicator.startedAt)
    );
    if (remaining === 0) {
      this.#clearIndicator(key, indicator);
    } else {
      indicator.timer = setTimeout(
        () => this.#clearIndicator(key, indicator),
        remaining
      );
    }
  }

  #fingerprintFor(raw) {
    return checklistFingerprint(
      raw,
      this.#checkboxSources,
      this.#includesLegacy
    );
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

  #refreshPost(reportError = false) {
    const refresh = this.#postModel.topic?.postStream?.refreshPost(
      this.#postModel.id
    );
    if (refresh) {
      void refresh.catch(reportError ? popupAjaxError : () => {});
    }
  }

  async #save() {
    if (this.#saving) {
      return;
    }

    this.#saving = true;
    try {
      while (this.#intents.size > 0) {
        let entries = [...this.#intents].map(([key, intent]) => [
          key,
          { ...intent },
        ]);
        let retries = 0;

        while ((entries = this.#currentEntries(entries)).length > 0) {
          if (!(await this.#hydrate(entries))) {
            break;
          }
          entries = this.#currentEntries(entries);
          if (entries.length === 0) {
            break;
          }

          const fingerprint = entries[0][1].fingerprint;
          const baselineFingerprint = this.#fingerprintFor(this.#baselineRaw);
          if (
            fingerprint === undefined ||
            baselineFingerprint === undefined ||
            fingerprint !== baselineFingerprint
          ) {
            this.#failBatch(entries);
            entries.forEach(([key]) => this.#clearIndicator(key));
            this.#discardIntents();
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
            const response = await ajax("/checklist/toggle", {
              type: "PUT",
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
                this.#fingerprintFor(baseline.raw) === fingerprint;
              this.#applyBaseline(baseline.raw, baseline.updatedAt);
              if (canRetry) {
                retries += 1;
                continue;
              }

              this.#failBatch(entries);
              this.#refreshPost();
              break;
            }

            if (this.#fingerprint !== fingerprint) {
              this.#applyBaseline(
                this.#postModel.raw,
                this.#postModel.updated_at
              );
              this.#refreshPost();
              break;
            }

            this.#postModel.last_editor_id = response.last_editor_id;
            this.#postModel.updated_at = response.updated_at;
            this.#postModel.version = response.version;
            this.#postModel.raw = response.raw;
            this.#applyBaseline(response.raw, response.updated_at);
            this.#completeBatch(entries);
            if (this.#intents.size === 0) {
              this.#postModel.cooked = response.cooked;
            }
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
              this.#fingerprintFor(baseline.raw) === entries[0][1].fingerprint;

            if (canRetry) {
              this.#applyBaseline(baseline.raw, baseline.updatedAt);
              retries += 1;
              continue;
            }

            this.#failBatch(entries);
            if (baseline) {
              this.#applyBaseline(baseline.raw, baseline.updatedAt);
            } else if (!error.jqXHR || error.jqXHR.status === 0) {
              this.#baselineRaw = undefined;
            } else if (this.#postModel.raw != null) {
              this.#applyBaseline(
                this.#postModel.raw,
                this.#postModel.updated_at
              );
            }
            this.#refreshPost();
            popupAjaxError(error);
            break;
          }
        }
      }
    } finally {
      this.#saving = false;
    }
  }

  async #hydrate(entries) {
    if (this.#baselineRaw != null) {
      return true;
    }

    try {
      const post = await ajax(`/posts/${this.#postModel.id}`);
      const baseline = this.#freshestBaseline(post.raw, post.updated_at);
      const fingerprint = this.#fingerprintFor(baseline.raw);
      const canUseBaseline =
        timestampsAreEqual(this.#baselineUpdatedAt, baseline.updatedAt) ||
        (this.#fingerprint !== undefined && fingerprint === this.#fingerprint);
      if (!canUseBaseline || fingerprint === undefined) {
        this.#failBatch(entries);
        entries.forEach(([key]) => this.#clearIndicator(key));
        this.#refreshPost(true);
        return false;
      }

      this.#fingerprint = fingerprint;
      entries.forEach(([, intent]) => (intent.fingerprint = fingerprint));
      for (const intent of this.#intents.values()) {
        intent.fingerprint ??= fingerprint;
      }
      this.#applyBaseline(baseline.raw, baseline.updatedAt);
      if (this.#postModel.raw == null) {
        this.#postModel.raw = baseline.raw;
      }
      return true;
    } catch (error) {
      this.#failBatch(entries);
      popupAjaxError(error);
      return false;
    }
  }

  #startIndicator(key) {
    const existing = this.#indicators.get(key);
    clearTimeout(existing?.timer);
    this.#indicators.set(key, { startedAt: performance.now() });
    const box = this.#binding?.controls.get(key);
    box?.classList.add("is-pending");
    box?.setAttribute("aria-busy", "true");
  }

  #syncControl(key, box) {
    const intent = this.#intents.get(key);
    if (intent) {
      setCheckboxState(box, intent.checked);
    }

    const indicator = this.#indicators.get(key);
    box.classList.toggle("is-pending", Boolean(indicator));
    if (intent) {
      box.setAttribute("aria-busy", "true");
    } else {
      box.removeAttribute("aria-busy");
    }
  }
}

function addToggleBehavior(boxes, postModel, allBoxes = boxes) {
  let checklistState = checklistStates.get(postModel);
  if (!checklistState) {
    checklistState = new ChecklistState(postModel);
    checklistStates.set(postModel, checklistState);
  }
  return checklistState.bind(boxes, allBoxes);
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
