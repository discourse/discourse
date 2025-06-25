import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { modifier } from "ember-modifier";
import DAutocompleteResults from "discourse/components/d-autocomplete/results";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import DMenu from "float-kit/components/d-menu";

/**
 * Modern autocomplete component using FloatKit for positioning
 * Direct 1:1 replacement for jQuery autocomplete
 *
 * @component DAutocomplete
 *
 * @param {string} key - Trigger character (e.g., "@", "#", ":")
 * @param {Function} dataSource - Async function to fetch results: (term) => Promise<Array>
 * @param {Component} [template] - Custom result item template component
 * @param {Function} [transformComplete] - Transform completion before insertion
 * @param {Function} [afterComplete] - Callback after completion
 * @param {boolean} [debounced=true] - Enable debounced search
 */
export default class DAutocomplete extends Component {
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

  // Modifier to set up autocomplete on target element
  setupAutocomplete = modifier((element) => {
    this.targetElement = element;

    // Set up event listeners
    element.addEventListener("keyup", this.handleKeyUp);
    element.addEventListener("keydown", this.handleKeyDown);
    element.addEventListener("paste", this.handlePaste);

    // Cleanup
    return () => {
      element.removeEventListener("keyup", this.handleKeyUp);
      element.removeEventListener("keydown", this.handleKeyDown);
      element.removeEventListener("paste", this.handlePaste);
      this.cleanup();
    };
  });

  willDestroy() {
    super.willDestroy();
    this.cleanup();
  }

  cleanup() {
    cancel(this.debouncedSearch);
    this.searchPromise?.cancel?.();
    this.expanded = false;
  }

  get shouldDebounce() {
    return this.args.debounced ?? false;
  }

  get menuIdentifier() {
    return `autocomplete-${this.args.key || "default"}`;
  }

  @action
  handleKeyUp(event) {
    // Skip if modifier keys are pressed
    if (event.ctrlKey || event.altKey || event.metaKey) {
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

  @action
  handleKeyDown(event) {
    // Handle navigation when autocomplete is open
    if (this.expanded) {
      switch (event.key) {
        case "ArrowUp":
          event.preventDefault();
          this.moveSelection(-1);
          break;
        case "ArrowDown":
          event.preventDefault();
          this.moveSelection(1);
          break;
        case "Enter":
        case "Tab":
          event.preventDefault();
          if (this.selectedIndex >= 0) {
            this.selectResult(this.results[this.selectedIndex], event);
          }
          break;
        case "Escape":
          event.preventDefault();
          this.close();
          break;
        case "ArrowRight":
          // Allow right arrow to close autocomplete if at end of word
          if (this.targetElement.value[this.getCaretPosition()] === " ") {
            this.close();
          }
          break;
        case "Backspace":
          // Handle backspace to potentially reopen autocomplete
          this.handleBackspace(event);
          break;
      }
    } else {
      // Handle backspace when closed to potentially reopen
      if (event.key === "Backspace") {
        this.handleBackspace(event);
      }
    }
  }

  @action
  handlePaste(event) {
    // Trigger autocomplete check after paste
    setTimeout(() => {
      this.performAutocomplete(event);
    }, 50);
  }

  @action
  async performAutocomplete() {
    const caretPosition = this.getCaretPosition();
    const value = this.targetElement.value;
    const key = value[caretPosition - 1];

    // Check if we should trigger autocomplete
    if (this.completeStart === null && caretPosition > 0) {
      if (key === this.args.key) {
        const prevChar = value.charAt(caretPosition - 2);
        if (!prevChar || this.ALLOWED_LETTERS_REGEXP.test(prevChar)) {
          this.completeStart = caretPosition - 1;
          await this.performSearch("");
        }
      }
    } else if (this.completeStart !== null) {
      // Extract search term
      const term = value.substring(
        this.completeStart + (this.args.key ? 1 : 0),
        caretPosition
      );

      // Validate we're still in autocomplete context
      if (!this.args.key || value[this.completeStart] === this.args.key) {
        await this.performSearch(term);
      } else {
        this.close();
      }
    }
  }

  @action
  async handleBackspace() {
    if (this.completeStart === null && this.args.key) {
      const position = await this.guessCompletePosition({ backSpace: true });
      if (position.completeStart !== null) {
        this.completeStart = position.completeStart;
        await this.performSearch(position.term || "");
      }
    }
  }

  @action
  async performSearch(term) {
    // Skip if same term (basic caching)
    if (this.previousTerm === term && !this.args.forceRefresh) {
      return;
    }

    this.previousTerm = term;
    this.searchTerm = term;

    // Close if only whitespace or invalid context
    if (
      (term.length !== 0 && term.trim().length === 0) ||
      this.targetElement.value[this.getCaretPosition()]?.trim()
    ) {
      this.close();
      return;
    }

    // Cancel previous search
    if (this.searchPromise?.cancel) {
      this.searchPromise.cancel();
    }

    this.isLoading = true;

    try {
      this.searchPromise = this.args.dataSource(term);
      const results = await this.searchPromise;

      if (results === "skip" || results === "__CANCELLED") {
        return;
      }

      this.updateResults(results || []);
    } catch (error) {
      if (error.name !== "AbortError") {
        this.results = [];
        this.close();
      }
    } finally {
      this.isLoading = false;
      this.searchPromise = null;
    }
  }

  @action
  updateResults(results) {
    this.results = results;

    if (this.results.length === 0) {
      this.close();
    } else {
      this.selectedIndex = 0; // Always auto-select first
      this.show();
    }
  }

  @action
  show() {
    if (!this.expanded) {
      this.expanded = true;
      this.menuInstance?.show?.();
    }
  }

  @action
  close() {
    if (this.expanded) {
      this.expanded = false;
      this.completeStart = null;
      this.searchTerm = "";
      this.results = [];
      this.selectedIndex = -1;
      this.previousTerm = null;

      cancel(this.debouncedSearch);
      this.searchPromise?.cancel?.();

      this.menuInstance?.close?.();
    }
  }

  @action
  moveSelection(direction) {
    if (this.results.length === 0) {
      return;
    }

    this.selectedIndex = Math.max(
      0,
      Math.min(this.results.length - 1, this.selectedIndex + direction)
    );
  }

  @action
  async selectResult(result, event) {
    await this.completeTextareaTerm(result, event);
    this.close();
  }

  @action
  async completeTextareaTerm(term, event) {
    if (!term) {
      return;
    }

    // Transform if needed
    if (this.args.transformComplete) {
      term = await this.args.transformComplete(term, event);
    }

    if (!term) {
      return;
    }

    // Simple text replacement
    const value = this.targetElement.value;
    const preserveKey = this.args.preserveKey ?? true;
    const replacement = (preserveKey ? this.args.key || "" : "") + term;

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

    // Call afterComplete callback
    this.args.afterComplete?.(this.targetElement.value, event);
  }

  async guessCompletePosition(opts = {}) {
    let caretPos = this.getCaretPosition();
    const value = this.targetElement.value;

    if (opts.backSpace) {
      caretPos -= 1;
    }

    let start = null;
    let term = null;
    const initialCaretPos = caretPos;

    while (caretPos >= 0) {
      caretPos -= 1;
      const prev = value[caretPos];

      if (prev === this.args.key) {
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

  getCaretPosition() {
    return this.targetElement.selectionStart || 0;
  }

  @action
  handleMenuRegister(menuInstance) {
    this.menuInstance = menuInstance;
  }

  <template>
    <DMenu
      @identifier={{this.menuIdentifier}}
      @placement="bottom-start"
      @offset={{2}}
      @modalForMobile={{true}}
      @closeOnClickOutside={{false}}
      @trapTab={{false}}
      @onRegisterApi={{this.handleMenuRegister}}
    >
      <:trigger>
        {{yield (hash setupAutocomplete=this.setupAutocomplete)}}
      </:trigger>

      <:content>
        {{#if this.expanded}}
          <DAutocompleteResults
            @results={{this.results}}
            @selectedIndex={{this.selectedIndex}}
            @searchTerm={{this.searchTerm}}
            @isLoading={{this.isLoading}}
            @template={{@template}}
            @onSelectResult={{this.selectResult}}
          />
        {{/if}}
      </:content>
    </DMenu>
  </template>
}
