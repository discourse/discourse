import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import { modifier } from "ember-modifier";
import type { DRovingFocusApi } from "discourse/ui-kit/modifiers/d-roving-focus";
import type SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type SelectListPresenter from "discourse/ui-kit/select/-internals/coordinators/select-list-presenter";
import type WindowedListCoordinator from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import type SelectEngine from "discourse/ui-kit/select/select-engine";

/** Owns focus and cursor authority for a list that stays mounted while unfocused. */
export default class SelectListInteraction {
  @tracked filterInput: HTMLInputElement | null = null;
  @tracked focused = false;
  @tracked listboxElement: HTMLElement | null = null;
  @tracked root: HTMLElement | null = null;

  session = 0;

  /** Registers the persistent root and its delegated focus and chip-press handlers. */
  registerRoot = modifier((element: HTMLElement) => {
    this.root = element;
    element.addEventListener("focusin", this.#handleFocusIn);
    element.addEventListener("focusout", this.#handleFocusOut);
    element.addEventListener("mousedown", this.#handleRootMousedown);
    return () => {
      element.removeEventListener("focusin", this.#handleFocusIn);
      element.removeEventListener("focusout", this.#handleFocusOut);
      element.removeEventListener("mousedown", this.#handleRootMousedown);
    };
  });

  /** Clears surviving cursors after a cap, query or focus transition. */
  watchCursor = modifier(() => {
    const canSeed = this.canSeed;
    const check = schedule("afterRender", () => {
      if (!canSeed && !this.#destroyed) {
        this.#clearCursor();
      }
    });
    return () => cancel(check);
  });

  #announcer: SelectAnnouncer;
  #engine: SelectEngine;
  #listbox: WindowedListCoordinator;
  #presenter: SelectListPresenter;
  #roving: DRovingFocusApi | null = null;
  #stripRoving: DRovingFocusApi | null = null;
  #focusCheck?: ReturnType<typeof schedule>;
  #destroyed = false;

  #handleFocusIn = (): void => {
    this.focused = true;
  };

  /** Removed chips can report null relatedTarget before their replacement takes focus. */
  #handleFocusOut = (): void => {
    cancel(this.#focusCheck);
    this.#focusCheck = schedule("afterRender", () => {
      if (this.#destroyed || this.root?.contains(document.activeElement)) {
        return;
      }
      this.focused = false;
      this.session++;
      this.#announcer.cancelPending();
      this.#clearCursor();
    });
  };

  /** Chip presses keep focus in this select's search, as option presses do. */
  #handleRootMousedown = (event: MouseEvent): void => {
    if (
      event.target instanceof Element &&
      event.target.closest(".d-select__strip-remove")
    ) {
      this.preventPointerBlur(event);
    }
  };

  constructor(options: {
    /** The shared announcement owner. */
    announcer: SelectAnnouncer;
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The mounted results coordinator. */
    listbox: WindowedListCoordinator;
    /** Live presentation and lock state. */
    presenter: SelectListPresenter;
  }) {
    this.#announcer = options.announcer;
    this.#engine = options.engine;
    this.#listbox = options.listbox;
    this.#presenter = options.presenter;
    registerDestructor(this, () => {
      this.#destroyed = true;
      cancel(this.#focusCheck);
      this.#announcer.cancelPending();
    });
  }

  get canSeed(): boolean {
    return (
      this.focused &&
      this.#engine.filter.length > 0 &&
      !this.#engine.atMaximum &&
      !this.#presenter.isLocked
    );
  }

  /** Rechecks DOM ownership when a deferred announcement fires. */
  canReport(): boolean {
    return this.focused && !!this.root?.contains(document.activeElement);
  }

  /** Re-reports a mounted limit hint when focus returns. */
  @action
  reportLimit(element: HTMLElement, [message]: [string, boolean]): void {
    this.#announcer.announceLimit(element, [message]);
  }

  /** Re-reports a mounted query hint when focus returns. */
  @action
  reportMinChars(element: HTMLElement, [remaining]: [number, boolean]): void {
    this.#announcer.announceMinChars(element, [remaining]);
  }

  @action
  registerFilter(element: HTMLInputElement): void {
    this.filterInput = element;
  }

  @action
  registerListbox(element: HTMLElement | null): void {
    this.listboxElement = element;
  }

  @action
  registerRoving(api: DRovingFocusApi | null): void {
    this.#roving = api;
    this.#listbox.registerListboxRoving(api);
    if (!this.canSeed) {
      this.#clearCursor();
    }
  }

  @action
  registerStripRoving(api: DRovingFocusApi | null): void {
    this.#stripRoving = api;
  }

  @action
  focusStrip(index: number): boolean {
    return this.#stripRoving?.focusIndex(index) ?? false;
  }

  @action
  focusInput(): void {
    this.filterInput?.focus({ preventScroll: true });
  }

  /** Takes ownership before a press; preventing default alone cannot move sibling focus. */
  @action
  preventPointerBlur(event: MouseEvent): void {
    if (event.button !== 0 || this.#presenter.isDisabled) {
      return;
    }
    event.preventDefault();
    this.focusInput();
  }

  @action
  handleInputKeydown(event: KeyboardEvent): void {
    if (event.isComposing || this.#presenter.isLocked) {
      return;
    }
    const input = this.filterInput;
    if (event.target !== input || !input) {
      return;
    }
    if (
      event.key === "Backspace" &&
      input.value === "" &&
      this.#engine.hasValue
    ) {
      event.preventDefault();
      this.#engine.deselectLast();
    } else if (
      event.key === "ArrowLeft" &&
      input.selectionStart === 0 &&
      input.selectionEnd === 0 &&
      this.#engine.hasValue
    ) {
      event.preventDefault();
      this.#stripRoving?.focusLast();
    } else if (
      event.key === "Enter" &&
      !input.hasAttribute("aria-activedescendant") &&
      !this.#engine.belowMinChars &&
      (this.#engine.serverPending || this.#engine.serverAwaitingFirstPage) &&
      !this.#engine.serverRevealPending
    ) {
      event.preventDefault();
      event.stopImmediatePropagation();
      this.#announcer.announceStillLoading();
    }
  }

  #clearCursor(): void {
    this.#roving?.clear();
    this.#listbox.clearCursor();
    this.filterInput?.removeAttribute("aria-activedescendant");
  }
}
