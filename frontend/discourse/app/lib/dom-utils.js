/**
 * Forces focus on a DOM element by making it focusable if it isn't already.
 * This function temporarily adds a tabindex attribute if necessary and removes it
 * when the element loses focus.
 *
 * @param {HTMLElement} element - The DOM element to force focus on
 * @throws {TypeError} If element is not a valid DOM element
 * @example
 * // Make a div focusable and focus it
 * const div = document.querySelector('#myDiv');
 * forceFocus(div);
 *
 * @example
 * // Focus an element that's already focusable (like an input)
 * const input = document.querySelector('input');
 * forceFocus(input);
 */
export function forceFocus(element) {
  // Validate input
  if (!element || !(element instanceof Element)) {
    throw new TypeError("forceFocus requires a valid DOM element");
  }

  // Check if element is naturally focusable or has tabindex
  const isNaturallyFocusable = isElementNaturallyFocusable(element);
  const hasTabindex = element.getAttribute("tabindex") !== null;
  const isFocusable = isNaturallyFocusable || hasTabindex;

  if (!isFocusable) {
    // force the attribute to be -1 so that the element is focusable
    element.setAttribute("tabindex", "-1");
  }

  element.focus();

  if (!isFocusable) {
    element.addEventListener(
      "blur",
      () => {
        // Only remove if we added it and it hasn't been changed
        if (element.getAttribute("tabindex") === "-1") {
          element.removeAttribute("tabindex");
        }
      },
      {
        once: true,
        passive: true,
        capture: true,
      }
    );
  }
}

/**
 * Checks if an element is naturally focusable without tabindex
 * @param {Element} element - The element to check
 * @returns {boolean} True if element is naturally focusable
 */
function isElementNaturallyFocusable(element) {
  const tagName = element.tagName.toLowerCase();

  // Check for naturally focusable elements
  if (["input", "textarea", "select", "button"].includes(tagName)) {
    return !element.disabled;
  }

  if (tagName === "a" || tagName === "area") {
    return element.hasAttribute("href");
  }

  if (["iframe", "object", "embed"].includes(tagName)) {
    return true;
  }

  if (element.hasAttribute("contenteditable")) {
    return element.getAttribute("contenteditable") !== "false";
  }

  return false;
}

function offset(element) {
  // note that getBoundingClientRect forces a reflow.
  // When used in critical performance conditions
  // you might want to move to more involved solution
  // such as implementing an IntersectionObserver and
  // using its boundingClientRect property
  const rect = element.getBoundingClientRect();
  return {
    top: rect.top + window.scrollY,
    left: rect.left + window.scrollX,
  };
}

function position(element) {
  return {
    top: element.offsetTop,
    left: element.offsetLeft,
  };
}

export default { offset, position };
