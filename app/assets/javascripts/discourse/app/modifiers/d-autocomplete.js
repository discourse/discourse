import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import Modifier from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

/**
 * Class-based modifier for adding autocomplete functionality to input elements
 * Preserves exact CSS structure for backward compatibility
 *
 * @class DAutocompleteModifier
 * @param {string} key - Trigger character (e.g., "@", "#", ":")
 * @param {Function} dataSource - Async function to fetch results: (term) => Promise<Array>
 * @param {Function} [transformComplete] - Transform completion before insertion
 * @param {Function} [afterComplete] - Callback after completion
 * @param {boolean} [debounced=false] - Enable debounced search
 * @param {boolean} [preserveKey=true] - Include trigger key in completion
 * @param {Function} [template] - Custom template function for results
 * @param {boolean} [autoSelectFirstSuggestion=true] - Auto-select first result
 */
export default class DAutocompleteModifier extends Modifier {
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
  autocompleteDiv = null;
  menuService = null;

  // Constants
  ALLOWED_LETTERS_REGEXP = /[\s[{(/+]/;

  handleKeyUp = (event) => {
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
  };

  handleKeyDown = (event) => {
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
          event.stopPropagation();
          this.closeAutocomplete();
          break;
        case "ArrowRight":
          // Allow right arrow to close autocomplete if at end of word
          if (this.targetElement.value[this.getCaretPosition()] === " ") {
            this.closeAutocomplete();
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
  };

  handlePaste = (event) => {
    // Trigger autocomplete check after paste
    setTimeout(() => {
      this.performAutocomplete(event);
    }, 50);
  };

  handleElementClick = (event) => {
    // Stop propagation to prevent global click handler from closing
    event.stopPropagation();
  };

  handleGlobalClick = () => {
    if (this.expanded) {
      this.closeAutocomplete();
    }
  };

  constructor(owner, args) {
    super(owner, args);
    this.menuService = getOwner(this).lookup("service:menu");
  }

  willDestroy() {
    super.willDestroy();
    this.cleanup();

    if (this.targetElement) {
      this.targetElement.removeEventListener("keyup", this.handleKeyUp);
      this.targetElement.removeEventListener("keydown", this.handleKeyDown);
      this.targetElement.removeEventListener("paste", this.handlePaste);
      this.targetElement.removeEventListener("click", this.handleElementClick);
    }

    document.removeEventListener("click", this.handleGlobalClick);
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
    this.closeAutocomplete();
  }

  get shouldDebounce() {
    return this.options.debounced ?? false;
  }

  get autoSelectFirstSuggestion() {
    return this.options.autoSelectFirstSuggestion ?? true;
  }

  async performAutocomplete() {
    const caretPosition = this.getCaretPosition();
    const value = this.targetElement.value;
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
        this.closeAutocomplete();
      }
    }
  }

  async handleBackspace() {
    if (this.completeStart === null && this.options.key) {
      const position = await this.guessCompletePosition({ backSpace: true });
      if (position.completeStart !== null) {
        this.completeStart = position.completeStart;
        await this.performSearch(position.term || "");
      }
    }
  }

  async performSearch(term) {
    // Skip if same term (basic caching)
    if (this.previousTerm === term && !this.options.forceRefresh) {
      return;
    }

    this.previousTerm = term;
    this.searchTerm = term;

    // Close if only whitespace or invalid context
    if (
      (term.length !== 0 && term.trim().length === 0) ||
      this.targetElement.value[this.getCaretPosition()]?.trim()
    ) {
      this.closeAutocomplete();
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

      if (results === "skip" || results === "__CANCELLED") {
        return;
      }

      this.updateResults(results || []);
    } catch (error) {
      if (error.name !== "AbortError") {
        this.results = [];
        this.closeAutocomplete();
      }
    } finally {
      this.isLoading = false;
      this.searchPromise = null;
    }
  }

  updateResults(results) {
    this.results = results;

    if (this.results.length === 0) {
      this.closeAutocomplete();
    } else {
      this.selectedIndex = this.autoSelectFirstSuggestion ? 0 : -1;
      this.renderAutocomplete();
    }
  }

  renderAutocomplete() {
    if (this.autocompleteDiv) {
      this.autocompleteDiv.remove();
    }

    if (this.results.length === 0) {
      return;
    }

    // Create autocomplete container with exact CSS classes for compatibility
    this.autocompleteDiv = document.createElement("div");
    this.autocompleteDiv.className = "autocomplete ac-user";

    const ul = document.createElement("ul");

    this.results.forEach((result, index) => {
      const li = document.createElement("li");
      const a = document.createElement("a");

      if (index === this.selectedIndex) {
        a.className = "selected";
      }

      // Use custom template if provided, otherwise default structure
      if (this.options.template) {
        a.innerHTML = this.options.template(result);
      } else {
        // Default user autocomplete structure
        a.innerHTML = this.getDefaultTemplate(result);
      }

      a.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.selectedIndex = index;
        this.selectResult(result, event);
      });

      li.appendChild(a);
      ul.appendChild(li);
    });

    this.autocompleteDiv.appendChild(ul);

    // Position the autocomplete div
    this.positionAutocomplete();

    // Add to DOM
    document.body.appendChild(this.autocompleteDiv);
    this.expanded = true;

    // Call onRender callback if provided
    this.options.onRender?.(this.results);
  }

  getDefaultTemplate(result) {
    // Default template maintaining CSS compatibility
    if (typeof result === "string") {
      return `<span class="username">${result}</span>`;
    }

    if (result.username) {
      let html = `<span class="username">${result.username}</span>`;
      if (result.avatar_template) {
        const avatar = result.avatar_template.replace("{size}", "25");
        html = `<img class="avatar" src="${avatar}" width="25" height="25"> ${html}`;
      }
      if (result.name) {
        html += `<span class="name">${result.name}</span>`;
      }
      return html;
    }

    return result.toString();
  }

  positionAutocomplete() {
    if (!this.autocompleteDiv || !this.targetElement) {
      return;
    }

    const targetRect = this.targetElement.getBoundingClientRect();
    const caretCoords = this.getCaretCoords();

    // Basic positioning - below the element
    this.autocompleteDiv.style.position = "fixed";
    this.autocompleteDiv.style.left = `${targetRect.left + (caretCoords?.left || 0)}px`;
    this.autocompleteDiv.style.top = `${targetRect.bottom + 2}px`;
    this.autocompleteDiv.style.zIndex = "1000";
    this.autocompleteDiv.style.maxHeight = "200px";
    this.autocompleteDiv.style.overflowY = "auto";
  }

  @action
  closeAutocomplete() {
    if (this.autocompleteDiv) {
      this.autocompleteDiv.remove();
      this.autocompleteDiv = null;
    }

    this.expanded = false;
    this.completeStart = null;
    this.searchTerm = "";
    this.results = [];
    this.selectedIndex = -1;
    this.previousTerm = null;

    cancel(this.debouncedSearch);
    this.searchPromise?.cancel?.();

    this.options.onClose?.();
  }

  @action
  moveSelection(direction) {
    if (this.results.length === 0) {
      return;
    }

    const oldIndex = this.selectedIndex;
    this.selectedIndex = Math.max(
      -1,
      Math.min(this.results.length - 1, this.selectedIndex + direction)
    );

    // Update DOM selection classes
    if (this.autocompleteDiv) {
      const links = this.autocompleteDiv.querySelectorAll("a");
      if (links[oldIndex]) {
        links[oldIndex].classList.remove("selected");
      }
      if (links[this.selectedIndex]) {
        links[this.selectedIndex].classList.add("selected");
        links[this.selectedIndex].scrollIntoView({ block: "nearest" });
      }
    }
  }

  @action
  async selectResult(result, event) {
    await this.completeTextareaTerm(result, event);
    this.closeAutocomplete();
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

    // Simple text replacement
    const value = this.targetElement.value;
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

    // Call afterComplete callback
    this.options.afterComplete?.(this.targetElement.value, event);
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

  getCaretPosition() {
    return this.targetElement.selectionStart || 0;
  }

  getCaretCoords() {
    // Simple approximation - in real implementation you might want more sophisticated caret positioning
    try {
      const caretPos = this.getCaretPosition();
      const value = this.targetElement.value;
      const textBeforeCaret = value.substring(0, caretPos);

      // Create a temporary span to measure text width
      const span = document.createElement("span");
      span.style.font = window.getComputedStyle(this.targetElement).font;
      span.style.visibility = "hidden";
      span.style.position = "absolute";
      span.textContent = textBeforeCaret;

      document.body.appendChild(span);
      const width = span.offsetWidth;
      document.body.removeChild(span);

      return { left: width, top: 0 };
    } catch {
      return { left: 0, top: 0 };
    }
  }
}
