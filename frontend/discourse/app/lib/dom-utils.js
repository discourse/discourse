/**
 * Forces focus on a DOM element by making it focusable if it isn't already.
 * This function temporarily adds a tabindex attribute if necessary and removes it
 * when the element loses focus.
 *
 * @param {HTMLElement} element - The DOM element to force focus on
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
  // we want to ensure to capture the value of the tabindex attribute which may be different from the tabindex
  // property of the element.
  const isFocusable = element.getAttribute("tabindex") !== null;

  if (!isFocusable) {
    // force the attribute to be -1 so that the element is focusable
    element.setAttribute("tabindex", "-1");
  }

  element.focus();

  if (!isFocusable) {
    element.addEventListener(
      "blur",
      () => {
        // ensure tabindex it's still -1 before removing it
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
