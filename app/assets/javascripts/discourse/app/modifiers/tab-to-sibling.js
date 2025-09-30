import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

/**
 * Modifier that redirects tab navigation to focus sibling elements
 * instead of children within the element.
 *
 * Usage: {{tab-to-sibling}}
 *
 * When Tab is pressed on the element, it will focus the next sibling.
 * When Shift+Tab is pressed, it will focus the previous sibling.
 * If no focusable sibling is found, falls back to default behavior.
 *
 * @example
 * // Use on list items to navigate between them instead of focusing children
 * <div class="search-results">
 *   {{#each items as |item|}}
 *     <div class="search-result" {{tab-to-sibling}} tabindex="0">
 *       <h3>{{item.title}}</h3>
 *       <button>Action</button>  <!-- Tab won't focus this -->
 *     </div>
 *   {{/each}}
 * </div>
 *
 * @example
 * // Use on cards to navigate between cards
 * <div class="card-container">
 *   <div class="card" {{tab-to-sibling}} tabindex="0">
 *     <input type="text" />  <!-- Tab won't focus this -->
 *   </div>
 *   <div class="card" {{tab-to-sibling}} tabindex="0">
 *     <textarea></textarea>  <!-- Tab won't focus this -->
 *   </div>
 * </div>
 *
 * @component TabToSiblingModifier
 */
export default class TabToSiblingModifier extends Modifier {
  /**
   * @param {object} owner - The owner object
   * @param {Array} args - Arguments passed to the modifier
   */
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  /**
   * Applies the modifier to the element
   * @param {Element} element - The DOM element to apply the modifier to
   */
  modify(element) {
    this.element = element;
    this.element.addEventListener("keydown", this.handleKeydown);
  }

  /**
   * Handles keydown events to manage tab navigation
   * @param {KeyboardEvent} event - The keyboard event
   */
  @bind
  handleKeydown(event) {
    if (event.key !== "Tab") {
      return;
    }

    const currentElement = this.element;
    let targetSibling = null;

    if (event.shiftKey) {
      // Shift+Tab: focus previous sibling
      targetSibling = this.findFocusableSibling(currentElement, "previous");
    } else {
      // Tab: focus next sibling
      targetSibling = this.findFocusableSibling(currentElement, "next");
    }

    if (targetSibling) {
      event.preventDefault();
      targetSibling.focus();
    }
  }

  /**
   * Finds the next or previous focusable sibling element
   * @param {Element} element - The current element
   * @param {string} direction - "next" or "previous"
   * @returns {Element|null} - The focusable sibling element or null
   */
  findFocusableSibling(element, direction) {
    const siblingProperty =
      direction === "next" ? "nextElementSibling" : "previousElementSibling";
    let sibling = element[siblingProperty];

    while (sibling) {
      if (this.isFocusable(sibling)) {
        return sibling;
      }
      sibling = sibling[siblingProperty];
    }

    return null;
  }

  /**
   * Checks if an element is focusable
   * @param {Element} element - The element to check
   * @returns {boolean} - True if the element is focusable
   */
  isFocusable(element) {
    // Check if element has tabindex
    const tabindex = element.getAttribute("tabindex");
    if (tabindex === "-1") {
      return false;
    }

    // Check if element is naturally focusable or has positive tabindex
    const naturallyFocusable = [
      "A",
      "BUTTON",
      "INPUT",
      "SELECT",
      "TEXTAREA",
      "SUMMARY",
    ].includes(element.tagName);

    const hasTabindex = tabindex !== null && tabindex !== "-1";
    const isVisible = element.offsetParent !== null;
    const isNotDisabled = !element.disabled;

    return (naturallyFocusable || hasTabindex) && isVisible && isNotDisabled;
  }

  /**
   * Cleanup method called when the modifier is destroyed
   */
  cleanup() {
    this.element?.removeEventListener("keydown", this.handleKeydown);
  }
}
