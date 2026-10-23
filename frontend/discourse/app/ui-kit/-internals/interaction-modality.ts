/**
 * How the user last interacted with the page: a key press, a pointer press, or a "virtual"
 * interaction that arrived with neither, which is what assistive technology produces.
 */
export type InteractionModality = "keyboard" | "pointer" | "virtual";

let modality: InteractionModality = "pointer";
let hasEventBeforeFocus = false;
let hasBlurredWindowRecently = false;
let installed = false;

/**
 * Whether a click came from assistive technology, a keyboard or `element.click()` rather than
 * a pointer. Browsers report `detail` 0 for such clicks; NVDA and JAWS in Firefox send an empty
 * `pointerType`, and Android TalkBack sends a click with `buttons` set.
 *
 * @param event - The click to classify.
 */
export function isVirtualClick(event: MouseEvent): boolean {
  const pointerType = (event as PointerEvent).pointerType;
  if (pointerType === "" && event.isTrusted) {
    return true;
  }
  if (isAndroid() && pointerType) {
    return event.type === "click" && event.buttons === 1;
  }
  return event.detail === 0 && !pointerType;
}

/** The modality of the latest interaction; starts tracking on first use. */
export function interactionModality(): InteractionModality {
  trackInteractionModality();
  return modality;
}

/**
 * Whether a screen reader is likely driving a touch device: the latest interaction was virtual
 * on iOS or Android. Such readers ignore `aria-activedescendant`, so a list should take real
 * focus instead.
 *
 * @param platform - The device's platform flags.
 */
export function isTouchScreenReader(platform: {
  isIOS: boolean;
  isAndroid: boolean;
}): boolean {
  return (
    (platform.isIOS || platform.isAndroid) &&
    interactionModality() === "virtual"
  );
}

/** Installs the document listeners once; later calls do nothing. */
export function trackInteractionModality(): void {
  if (installed || typeof document === "undefined") {
    return;
  }
  installed = true;

  const pointer = () => {
    modality = "pointer";
    hasEventBeforeFocus = true;
  };
  document.addEventListener(
    "keydown",
    () => {
      modality = "keyboard";
      hasEventBeforeFocus = true;
    },
    true
  );
  document.addEventListener("pointerdown", pointer, true);
  document.addEventListener("mousedown", pointer, true);
  document.addEventListener(
    "click",
    (event) => {
      if (isVirtualClick(event)) {
        modality = "virtual";
        hasEventBeforeFocus = true;
      }
    },
    true
  );
  document.addEventListener(
    "focus",
    (event) => {
      if (event.target === document || event.target === window) {
        return;
      }
      // Focus with no key or pointer press before it was moved by assistive technology, unless
      // the window itself just regained focus and restored it.
      if (!hasEventBeforeFocus && !hasBlurredWindowRecently) {
        modality = "virtual";
      }
      hasEventBeforeFocus = false;
      hasBlurredWindowRecently = false;
    },
    true
  );
  window.addEventListener(
    "blur",
    () => {
      hasBlurredWindowRecently = true;
    },
    false
  );
}

function isAndroid(): boolean {
  return /Android/.test(navigator.userAgent);
}

trackInteractionModality();
