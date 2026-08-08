const FOCUSABLE_SELECTOR = [
  "input:not([disabled]):not([type=hidden])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "button:not([disabled])",
  "a[href]",
  "area[href]",
  "summary",
  "iframe",
  "object",
  "embed",
  "audio[controls]",
  "video[controls]",
  "[contenteditable]",
  "[tabindex]:not([disabled])",
].join(",");

const SKIPPABLE_SELECTORS = [
  "[aria-hidden='true']",
  "[aria-hidden='true'] *",
  "[inert]",
  "[inert] *",
];

export function getFocusableElements(container, additionalSkipSelectors = []) {
  if (!container) {
    return { safelyFocusableElements: [], safelyTabbableElements: [] };
  }

  const skipSelector = [
    ...additionalSkipSelectors,
    ...SKIPPABLE_SELECTORS,
  ].join(",");
  const elements = [
    ...(container.matches(FOCUSABLE_SELECTOR) ? [container] : []),
    ...container.querySelectorAll(FOCUSABLE_SELECTOR),
  ];
  const elementsWithData = elements.map((element) => ({
    element,
    tabbable: element.matches(':not([hidden]):not([tabindex^="-"])'),
    skippable:
      element.matches(skipSelector) ||
      !(
        element.offsetWidth ||
        element.offsetHeight ||
        element.getClientRects().length
      ),
  }));

  return {
    safelyFocusableElements: elementsWithData
      .filter(({ skippable }) => !skippable)
      .map(({ element }) => element),
    safelyTabbableElements: elementsWithData
      .filter(({ skippable, tabbable }) => tabbable && !skippable)
      .map(({ element }) => element),
  };
}
