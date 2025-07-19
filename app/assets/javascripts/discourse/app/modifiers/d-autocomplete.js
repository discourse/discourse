import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import DAutocompleteResults from "discourse/components/d-autocomplete-results";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

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

  // Internal state
  previousTerm = null;
  searchPromise = null;
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

  handleKeyUp(event) {
    // Skip if modifier keys are pressed
    if (this.hasModifierKey(event)) {
      return;
    }

    // Skip enter/escape as they're handled in keydown
    if (["Enter", "Escape"].includes(event.key)) {
      return;
    }

    if (this.shouldDebounce) {
      this.debouncedSearch = discourseDebounce(
        this,
        this.performAutocomplete,
        event,
        INPUT_DELAY
      );
    } else {
      this.performAutocomplete(event);
    }
  }

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
          // Skip if modifier keys are pressed (e.g., CMD+Backspace for line deletion)
          if (!this.hasModifierKey(event)) {
            return;
          }
          await this.handleBackspace(event);
          break;
      }
    } else {
      // Handle backspace when closed to potentially reopen
      if (event.key === "Backspace" && !this.hasModifierKey(event)) {
        await this.handleBackspace(event);
      }
    }
  }

  handlePaste(event) {
    // Trigger autocomplete check after paste
    setTimeout(() => {
      this.performAutocomplete(event);
    }, 50);
  }

  handleElementClick(event) {
    // Stop propagation to prevent global click handler from closing
    event.stopPropagation();
  }

  async handleGlobalClick() {
    if (this.expanded) {
      await this.closeAutocomplete();
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
    element.addEventListener("click", this.handleElementClick);

    // Global click handler to close autocomplete
    document.addEventListener("click", this.handleGlobalClick);
  }

  cleanup() {
    cancel(this.debouncedSearch);
    this.searchPromise?.cancel?.();
    if (this.targetElement) {
      this.targetElement.removeEventListener("keyup", this.handleKeyUp);
      this.targetElement.removeEventListener("keydown", this.handleKeyDown);
      this.targetElement.removeEventListener("paste", this.handlePaste);
      this.targetElement.removeEventListener("click", this.handleElementClick);
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
        await this.performSearch(term);
      } else {
        await this.closeAutocomplete();
      }
    }
  }

  async handleBackspace() {
    if (this.completeStart === null && this.options.key) {
      const position = await this.guessCompletePosition({ backSpace: true });
      if (position.completeStart !== null) {
        this.completeStart = position.completeStart;
        await this.performAutocomplete();
      }
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

    // Cancel previous search
    if (this.searchPromise?.cancel) {
      this.searchPromise.cancel();
    }

    this.isLoading = true;

    try {
      this.searchPromise = this.options.dataSource(term);
      const results = await this.searchPromise;

      if (
        this.isDestroying ||
        this.isDestroyed ||
        results === "skip" ||
        results === CANCELLED_STATUS
      ) {
        return;
      }

      await this.updateResults(results || []);
    } catch (e) {
      if (e.name !== "AbortError") {
        this.results = [];
        await this.closeAutocomplete();
      } else {
        // eslint-disable-next-line no-console
        console.error(e);
      }
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.isLoading = false;
        this.searchPromise = null;
      }
    }
  }

  async updateResults(results) {
    this.results = results;

    if (this.results.length === 0) {
      await this.closeAutocomplete();
    } else {
      this.selectedIndex = this.autoSelectFirstSuggestion ? 0 : -1;
      await this.renderAutocomplete();
    }
  }

  async renderAutocomplete() {
    if (this.results.length === 0) {
      return;
    }

    // Close any existing menu first
    await this.menu.close("d-autocomplete");

    try {
      // Create virtual element positioned at the caret location
      const virtualElement = this.createVirtualElementAtCaret();

      const menuOptions = {
        identifier: "d-autocomplete",
        component: DAutocompleteResults,
        placement: "top-start",
        fallbackPlacements: ["bottom-start", "top-end", "bottom-end"],
        data: {
          results: this.results,
          selectedIndex: this.selectedIndex,
          onSelect: this.selectResult,
          template: this.options.template,
          registerComponent: (componentInstance) => {
            this.componentInstance = componentInstance;
          },
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
      console.error(e);
    }
  }

  @action
  async closeAutocomplete() {
    await this.menu.close("d-autocomplete");

    this.expanded = false;
    this.completeStart = null;
    this.searchTerm = "";
    this.results = [];
    this.selectedIndex = -1;
    this.previousTerm = null;
    this.menuInstance = null;
    this.componentInstance = null; // Clean up component reference

    cancel(this.debouncedSearch);
    this.searchPromise?.cancel?.();

    // Note: onClose callback is handled by the menu's onClose option
  }

  @action
  async moveSelection(direction) {
    if (this.results.length === 0) {
      return;
    }

    // Calculate new selectedIndex
    const newIndex = Math.max(
      0,
      Math.min(this.results.length - 1, this.selectedIndex + direction)
    );

    this.selectedIndex = newIndex;

    if (this.componentInstance && this.componentInstance.updateSelectedIndex) {
      this.componentInstance.updateSelectedIndex(this.selectedIndex);
    }
  }

  @action
  async selectResult(result, event) {
    await this.completeTextareaTerm(result, event);
    await this.closeAutocomplete();

    // Clear any cached search state to prevent showing stale results
    this.previousTerm = null;
    this.searchTerm = "";
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

    // Use external textHandler if provided (for integration with TextareaTextManipulation)
    if (this.options.textHandler) {
      const preserveKey = this.options.preserveKey ?? true;
      const replacement = (preserveKey ? this.options.key || "" : "") + term;

      // Use textHandler's replaceTerm method for consistent behavior
      this.options.textHandler.replaceTerm(
        this.completeStart,
        this.getCaretPosition() - 1,
        replacement
      );
    } else {
      // Simple text replacement (default behavior)
      const value = this.getValue();
      const preserveKey = this.options.preserveKey ?? true;
      const replacement = (preserveKey ? this.options.key || "" : "") + term;

      const newValue =
        value.substring(0, this.completeStart) +
        replacement +
        value.substring(this.getCaretPosition());

      this.targetElement.value = newValue;

      // Set cursor position after replacement
      const newCaretPos = this.completeStart + replacement.length;
      this.targetElement.setSelectionRange(newCaretPos, newCaretPos);

      // Trigger input event to notify other listeners
      this.targetElement.dispatchEvent(new Event("input", { bubbles: true }));
    }

    // Call afterComplete callback
    this.options.afterComplete?.(this.getValue(), event);
  }

  async guessCompletePosition(opts = {}) {
    let caretPos = this.getCaretPosition();
    const value = this.getValue();

    if (opts.backSpace) {
      caretPos -= 1;
    }

    let start = null;
    let term = null;
    const initialCaretPos = caretPos;

    while (caretPos >= 0) {
      caretPos -= 1;
      const prev = value[caretPos];

      if (prev === this.options.key) {
        const beforeTrigger = value[caretPos - 1];

        if (
          beforeTrigger === undefined ||
          this.ALLOWED_LETTERS_REGEXP.test(beforeTrigger)
        ) {
          start = caretPos;
          term = value.substring(caretPos + 1, initialCaretPos);
          break;
        }
      }

      const prevIsGood = !/\s/.test(prev);
      if (!prevIsGood) {
        break;
      }
    }

    return { completeStart: start, term };
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
        console.error(e);
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
