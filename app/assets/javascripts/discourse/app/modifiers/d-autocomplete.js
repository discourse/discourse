import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import DAutocompleteResults from "discourse/components/d-autocomplete-results";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { VISIBILITY_OPTIMIZERS } from "float-kit/lib/constants";

export const CANCELLED_STATUS = "__CANCELLED";

/**
 * Class-based modifier for adding autocomplete functionality to input elements
 * Preserves exact CSS structure for backward compatibility
 *
 * @class DAutocompleteModifier
 * @param {string} key - Trigger character (e.g., "@", "#", ":")
 * @param {Function} dataSource - Async function to fetch results: (term) => Promise<Array>
 * @param {Function} template - Template function that receives {options: results} and returns HTML
 * @param {Function} [transformComplete] - Transform completion before insertion
 * @param {Function} [afterComplete] - Callback after completion
 * @param {boolean} [debounced=false] - Enable debounced search
 * @param {boolean} [preserveKey=true] - Include trigger key in completion
 * @param {boolean} [autoSelectFirstSuggestion=true] - Auto-select first result
 */
export default class DAutocompleteModifier extends Modifier {
  /**
   * Static helper function to set up autocomplete on any element
   *
   * @param {Object} owner - Ember owner
   * @param {HTMLElement} element - The element to modify with autocomplete functionality
   * @param {Object} autocompleteHandler - Handler for text operations
   * @param {Object} options - Autocomplete options
   */
  static setupAutocomplete(owner, element, autocompleteHandler, options) {
    const modifier = new DAutocompleteModifier(owner, {
      named: {},
      positional: [],
    });

    const modifierOptions = {
      ...options,
      textHandler: autocompleteHandler,
    };

    modifier.modify(element, [modifierOptions]);
    return modifier;
  }

  @service menu;

  @tracked expanded = false;
  @tracked results = [];
  @tracked selectedIndex = -1;
  @tracked searchTerm = "";
  @tracked isLoading = false;
  @tracked completeStart = null;
  @tracked completeEnd = null;

  // Internal state
  previousTerm = null;
  debouncedSearch = null;
  targetElement = null;
  menuInstance = null;

  // Constants
  ALLOWED_LETTERS_REGEXP = /[\s[{(/+]/;
  TRIGGER_CHAR_RELATIVE_OFFSET = 9;
  VERTICAL_RELATIVE_OFFSET = 10;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  @action
  handleKeyUp(event) {
    // Skip if modifier keys are pressed or other keys handled in KeyDown
    if (
      this.hasModifierKey(event) ||
      ["Enter", "Escape", "Tab"].includes(event.key)
    ) {
      return;
    }

    if (this.shouldDebounce) {
      this.debouncedSearch = discourseDebounce(
        this,
        this.performAutocomplete,
        event,
        INPUT_DELAY
      );
      return;
    }
    // Handle potential async errors without blocking the UI
    this.performAutocomplete(event).catch((e) => {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] handleKeyup: ", e);
    });
  }

  @action
  async handleKeyDown(event) {
    // Handle navigation when autocomplete is open
    if (this.expanded) {
      switch (event.key) {
        case "ArrowUp":
          event.preventDefault();
          await this.moveSelection(-1);
          break;
        case "ArrowDown":
          event.preventDefault();
          await this.moveSelection(1);
          break;
        case "Enter":
        case "Tab":
          event.preventDefault();
          if (this.selectedIndex >= 0) {
            await this.selectResult(this.results[this.selectedIndex], event);
          }
          break;
        case "Escape":
          event.preventDefault();
          event.stopPropagation();
          await this.closeAutocomplete();
          break;
        case "ArrowRight":
          // Allow right arrow to close autocomplete if at end of word
          if (this.targetElement.value[this.getCaretPosition()] === " ") {
            await this.closeAutocomplete();
          }
          break;
        case "Backspace":
          // Handle backspace to potentially reopen autocomplete
          await this.handleBackspace(event);
          break;
      }
    } else {
      // Handle backspace when closed to potentially reopen,
      // skip if modifier keys are pressed - this prevents autocomplete from opening on full deletion
      if (event.key === "Backspace" && !this.hasModifierKey(event)) {
        await this.handleBackspace(event);
      }
    }
  }

  @action
  async handlePaste(event) {
    // Trigger autocomplete check after paste with proper async handling
    try {
      // Use requestAnimationFrame for better performance than setTimeout - less flickering
      await new Promise((resolve) => requestAnimationFrame(resolve));
      await this.performAutocomplete(event);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] handlePaste: ", e);
    }
  }

  @action
  async handleGlobalClick() {
    try {
      if (this.expanded) {
        await this.closeAutocomplete();
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] handleGlobalClick: ", e);
    }
  }

  hasModifierKey(event) {
    return event.ctrlKey || event.altKey || event.metaKey;
  }

  modify(element, [options]) {
    this.targetElement = element;
    this.options = options || {};

    // Set up event listeners
    element.addEventListener("keyup", this.handleKeyUp);
    element.addEventListener("keydown", this.handleKeyDown);
    element.addEventListener("paste", this.handlePaste);

    // Global click handler to close autocomplete
    document.addEventListener("click", this.handleGlobalClick);
  }

  @action
  cleanup() {
    cancel(this.debouncedSearch);
    if (this.targetElement) {
      this.targetElement.removeEventListener("keyup", this.handleKeyUp);
      this.targetElement.removeEventListener("keydown", this.handleKeyDown);
      this.targetElement.removeEventListener("paste", this.handlePaste);
    }

    document.removeEventListener("click", this.handleGlobalClick);
    this.menu.close("d-autocomplete");
  }

  get shouldDebounce() {
    return this.options.debounced ?? false;
  }

  get autoSelectFirstSuggestion() {
    return this.options.autoSelectFirstSuggestion ?? true;
  }

  async performAutocomplete() {
    const caretPosition = this.getCaretPosition();
    const value = this.getValue();
    const key = value[caretPosition - 1];

    // Check if we should trigger autocomplete
    if (this.completeStart === null && caretPosition > 0) {
      if (key === this.options.key) {
        const prevChar = value.charAt(caretPosition - 2);
        if (!prevChar || this.ALLOWED_LETTERS_REGEXP.test(prevChar)) {
          this.completeStart = caretPosition - 1;
          this.completeEnd = caretPosition - 1;
          await this.performSearch("");
        }
      }
    } else if (this.completeStart !== null) {
      // Extract search term
      const term = value.substring(
        this.completeStart + (this.options.key ? 1 : 0),
        caretPosition
      );

      // Validate we're still in autocomplete context
      if (!this.options.key || value[this.completeStart] === this.options.key) {
        this.completeEnd = caretPosition - 1;
        await this.performSearch(term);
      } else {
        await this.closeAutocomplete();
      }
    }
  }

  async handleBackspace() {
    try {
      if (this.completeStart === null && this.options.key) {
        const position = await this.guessCompletePosition({ backSpace: true });
        if (position.completeStart !== null) {
          this.completeStart = position.completeStart;
          this.completeEnd = this.getCaretPosition() - 1;
          await this.performAutocomplete();
        }
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] handleBackspace: ", e);
    }
  }

  async performSearch(term) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    // Skip if same term (basic caching)
    if (this.previousTerm === term && !this.options.forceRefresh) {
      return;
    }

    this.previousTerm = term;
    this.searchTerm = term;

    // Close if only whitespace or invalid context
    if (
      (term.length !== 0 && term.trim().length === 0) ||
      this.getValue()[this.getCaretPosition()]?.trim()
    ) {
      await this.closeAutocomplete();
      return;
    }

    const results = this.options.dataSource(term);
    this.updateResults(results || []);
  }

  areResultsEqual(oldResults, newResults) {
    if (
      !oldResults ||
      !newResults ||
      oldResults.length !== newResults.length ||
      JSON.stringify(oldResults) !== JSON.stringify(newResults)
    ) {
      return false;
    }

    return true;
  }

  updateResults(results) {
    if (
      this.completeStart === null ||
      results === "skip" ||
      results === CANCELLED_STATUS
    ) {
      return;
    }

    if (results && results.then && typeof results.then === "function") {
      this.isLoading = true;
      results
        .then((r) => {
          this.isLoading = false;
          this.updateResults(r);
        })
        .catch((e) => {
          this.isLoading = false;
          if (e.name !== "AbortError") {
            // eslint-disable-next-line no-console
            console.error("[autocomplete] updateResults: ", e);
          }
          this.closeAutocomplete();
        });
      return;
    }

    // Check if results have actually changed to avoid unnecessary re-renders
    const resultsSame = this.areResultsEqual(this.results, results);
    const wasExpanded = this.expanded;

    this.results = results;

    if (!this.results || this.results.length === 0) {
      this.closeAutocomplete();
      return;
    }

    // If results are the same and menu is already open, don't close/reopen
    if (resultsSame && wasExpanded) {
      return;
    }

    this.selectedIndex = this.autoSelectFirstSuggestion ? 0 : -1;

    this.renderAutocomplete();
  }

  async renderAutocomplete() {
    if (this.results.length === 0) {
      return;
    }

    // If menu is already open, update the existing menu data instead of closing/reopening
    if (this.expanded && this.menuInstance) {
      try {
        // Update the menu data for the existing instance
        this.menuInstance.options.data = {
          getResults: () => this.results,
          getSelectedIndex: () => this.selectedIndex,
          onSelect: (result, index, event) => this.selectResult(result, event),
          template: this.options.template,
        };

        // Call onRender callback if provided
        this.options.onRender?.(this.results);
        return;
      } catch (e) {
        // If updating fails, fall back to close/reopen
        // eslint-disable-next-line no-console
        console.error(
          "[autocomplete] renderAutocomplete update failed, falling back: ",
          e
        );
        await this.menu.close("d-autocomplete");
      }
    } else {
      // Close any existing menu if we're not in the expected state
      await this.menu.close("d-autocomplete");
    }

    try {
      // Create virtual element positioned at the caret location
      const virtualElement = this.createVirtualElementAtCaret();

      const menuOptions = {
        identifier: "d-autocomplete",
        component: DAutocompleteResults,
        visibilityOptimizer: VISIBILITY_OPTIMIZERS.AUTO_PLACEMENT,
        placement: "top-start",
        allowedPlacements: [
          "top-start",
          "top-end",
          "bottom-start",
          "bottom-end",
        ],
        data: {
          getResults: () => this.results,
          getSelectedIndex: () => this.selectedIndex,
          onSelect: (result, index, event) => this.selectResult(result, event),
          template: this.options.template,
        },
        modalForMobile: false,
        onClose: () => {
          this.expanded = false;
          this.options.onClose?.();
        },
      };

      this.menuInstance = await this.menu.show(virtualElement, menuOptions);

      this.expanded = true;

      // Call onRender callback if provided
      this.options.onRender?.(this.results);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] renderAutocomplete: ", e);
    }
  }

  @action
  async closeAutocomplete() {
    await this.menu.close("d-autocomplete");

    this.expanded = false;
    this.completeStart = null;
    this.completeEnd = null;
    this.searchTerm = "";
    this.results = [];
    this.selectedIndex = -1;
    this.previousTerm = null;
    this.menuInstance = null;

    cancel(this.debouncedSearch);

    // Note: onClose callback is handled by the menu's onClose option
  }

  @action
  async moveSelection(direction) {
    try {
      if (this.results.length === 0) {
        return;
      }

      // Calculate new selectedIndex
      const newSelectedIndex = Math.max(
        0,
        Math.min(this.results.length - 1, this.selectedIndex + direction)
      );

      // Only update if the index actually changed
      if (newSelectedIndex !== this.selectedIndex) {
        this.selectedIndex = newSelectedIndex;
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] moveSelection: ", e);
    }
  }

  @action
  async selectResult(result, event) {
    try {
      await this.completeTextareaTerm(result, event);
      await this.closeAutocomplete();

      // Clear any cached search state to prevent showing stale results
      this.previousTerm = null;
      this.searchTerm = "";
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] selectResult error: ", e);
    }
  }

  @action
  async completeTextareaTerm(term, event) {
    if (!term) {
      return;
    }

    // Transform if needed
    if (this.options.transformComplete) {
      term = await this.options.transformComplete(term, event);
    }

    if (!term) {
      return;
    }

    const preserveKey = this.options.preserveKey ?? true;
    const replacement = (preserveKey ? this.options.key || "" : "") + term;

    // Recalculate position like the old autocomplete did to handle text changes
    const pos = await this.guessCompletePosition({ completeTerm: true });
    let completeEnd;
    let completeStart;

    if (pos.completeStart !== undefined && pos.completeEnd !== undefined) {
      completeStart = pos.completeStart;
      completeEnd = pos.completeEnd;
    } else {
      completeStart = completeEnd = this.getCaretPosition();
    }

    // Use textHandler's replaceTerm method for consistent behavior
    this.options.textHandler.replaceTerm(
      completeStart,
      completeEnd,
      replacement
    );

    this.options.afterComplete?.(this.getValue(), event);
  }

  async guessCompletePosition(opts = {}) {
    let prev, stopFound, term;
    let prevIsGood = true;
    let backSpace = opts?.backSpace;
    let completeTermOption = opts?.completeTerm;
    let caretPos = this.getCaretPosition();

    if (backSpace) {
      caretPos -= 1;
    }

    let start = null;
    let end = null;
    const initialCaretPos = caretPos;

    while (prevIsGood && caretPos >= 0) {
      caretPos -= 1;
      prev = this.getValue()[caretPos];

      stopFound = prev === this.options.key;

      if (stopFound) {
        prev = this.getValue()[caretPos - 1];

        if (prev === undefined || this.ALLOWED_LETTERS_REGEXP.test(prev)) {
          start = caretPos;
          term = this.getValue().substring(caretPos + 1, initialCaretPos);
          end = caretPos + term.length;
          break;
        }
      }

      prevIsGood = !/\s/.test(prev);
      if (completeTermOption) {
        prevIsGood ||= prev === " ";
      }
    }

    return { completeStart: start, completeEnd: end, term };
  }

  getValue() {
    return this.options.textHandler.getValue();
  }

  getCaretPosition() {
    return this.options.textHandler.getCaretPosition();
  }

  getAbsoluteCaretCoords() {
    // Use textHandler for accurate relative coordinate calculation
    if (this.options.textHandler && this.options.textHandler.getCaretCoords) {
      try {
        // Use completeStart position (where @ is) like legacy autocomplete does
        const position =
          this.completeStart !== null
            ? this.completeStart
            : this.getCaretPosition();
        const relativeCoords =
          this.options.textHandler.getCaretCoords(position);

        // Convert to absolute viewport coordinates
        const textareaRect = this.targetElement.getBoundingClientRect();

        return {
          x: textareaRect.left + relativeCoords.left,
          y: textareaRect.top + relativeCoords.top,
        };
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error("[autocomplete] getAbsoluteCaretCoords: ", e);
      }
    }

    // Fallback: return textarea position (will be inaccurate but won't crash)
    const textareaRect = this.targetElement.getBoundingClientRect();
    return {
      x: textareaRect.left,
      y: textareaRect.top,
    };
  }

  createVirtualElementAtCaret() {
    const caretCoords = this.getAbsoluteCaretCoords();
    return {
      getBoundingClientRect: () => ({
        left: caretCoords.x + this.TRIGGER_CHAR_RELATIVE_OFFSET,
        top: caretCoords.y + this.VERTICAL_RELATIVE_OFFSET,
        width: 1,
        height: 10,
      }),
    };
  }
}
