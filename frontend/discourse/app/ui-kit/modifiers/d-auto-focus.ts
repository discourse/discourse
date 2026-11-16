import Modifier from "ember-modifier";

interface DAutoFocusSignature {
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Whether to select the element's text after focusing it. Only text inputs and
       * textareas can select their text.
       */
      selectText?: boolean;
      /** Whether to keep the page from scrolling to the element. Defaults to `true`. */
      preventScroll?: boolean;
    };
  };
}

/**
 * Focuses the element when it is inserted. Later updates to its arguments do not
 * focus it again.
 */
export default class DAutoFocusModifier extends Modifier<DAutoFocusSignature> {
  didFocus = false;

  modify(
    element: HTMLElement,
    _: [],
    { selectText, preventScroll }: DAutoFocusSignature["Args"]["Named"]
  ) {
    if (!this.didFocus) {
      element.autofocus = true;
      element.focus({ preventScroll: preventScroll ?? true });

      if (selectText) {
        (element as HTMLInputElement | HTMLTextAreaElement).select();
      }

      this.didFocus = true;
    }
  }
}
