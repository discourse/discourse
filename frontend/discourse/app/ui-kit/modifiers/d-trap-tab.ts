import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import { focusOffScreen } from "discourse/modifiers/prevent-scroll-on-focus";
import type { CapabilitiesService } from "discourse/services/capabilities";

const FOCUSABLE_ELEMENTS =
  "details:not(.is-disabled) summary, [autofocus], a, input, select, textarea, summary";

interface DTrapTabSignature {
  /** The element the tab trap is attached to. */
  Element: HTMLElement;
  Args: {
    Named: {
      /** Whether focusing an element should prevent scrolling. Defaults to `true`. */
      preventScroll?: boolean;

      /** Whether to focus the first focusable element on setup. Defaults to `true`. */
      autofocus?: boolean;
    };
    Positional: [];
  };
}

export default class DTrapTabModifier extends Modifier<DTrapTabSignature> {
  @service declare capabilities: CapabilitiesService;

  #element: HTMLElement | null = null;
  #originalElement?: HTMLElement;
  #preventScroll = true;

  constructor(owner: Owner, args: ArgsFor<DTrapTabSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  modify(
    element: HTMLElement,
    _positional: [],
    { preventScroll, autofocus }: DTrapTabSignature["Args"]["Named"]
  ) {
    autofocus ??= true;
    this.#preventScroll = preventScroll ?? true;
    this.#originalElement = element;
    this.#element =
      element.querySelector<HTMLElement>(".d-modal__container") || element;
    this.#originalElement.addEventListener("keydown", this.trapTab);

    // on first trap we don't allow to focus modal-close
    // and apply manual focus only if we don't have any autofocus element
    const autofocusedElement =
      this.#element.querySelector<HTMLElement>("[autofocus]");

    if (
      autofocus &&
      (!autofocusedElement || document.activeElement !== autofocusedElement)
    ) {
      // if there's not autofocus, or the activeElement, is not the autofocusable element
      // attempt to focus the first of the focusable elements or just the modal-body
      // to make it possible to scroll with arrow down/up
      const target =
        autofocusedElement ||
        this.#element.querySelector<HTMLElement>(
          FOCUSABLE_ELEMENTS + ", button:not(.modal-close)"
        ) ||
        this.#element.querySelector<HTMLElement>(".d-modal__body");

      if (target) {
        target.focus({
          preventScroll: this.#preventScroll,
        });

        if (this.capabilities.isIOS) {
          focusOffScreen(target);
        }
      }
    }
  }

  @bind
  trapTab(event: KeyboardEvent) {
    if (event.key !== "Tab") {
      return;
    }

    const focusableElements = FOCUSABLE_ELEMENTS + ", button:enabled";

    const filteredFocusableElements = Array.from(
      this.#element.querySelectorAll<HTMLElement>(focusableElements)
    ).filter((element) => {
      const tabindex = element.getAttribute("tabindex");
      return tabindex !== "-1";
    });

    const firstFocusableElement = filteredFocusableElements[0];
    const lastFocusableElement =
      filteredFocusableElements[filteredFocusableElements.length - 1];

    if (event.shiftKey) {
      if (document.activeElement === firstFocusableElement) {
        lastFocusableElement?.focus();
        event.preventDefault();
      }
    } else {
      if (document.activeElement === lastFocusableElement) {
        event.preventDefault();
        (
          this.#element.querySelector<HTMLElement>(".modal-close") ||
          firstFocusableElement
        )?.focus({ preventScroll: this.#preventScroll });
      }
    }
  }

  #cleanup() {
    this.#originalElement?.removeEventListener("keydown", this.trapTab);
  }
}
