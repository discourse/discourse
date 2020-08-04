import { siteDir } from "discourse/lib/text-direction";

const D_POPOVER_ID = "d-popover";

const D_POPOVER_TEMPLATE = `
  <div id="${D_POPOVER_ID}" class="is-under">
    <div class="d-popover-arrow d-popover-top-arrow"></div>
    <div class="d-popover-content">
      <div class="spinner small"></div>
    </div>
    <div class="d-popover-arrow d-popover-bottom-arrow"></div>
  </div>
`;

const D_ARROW_HEIGHT = 10;

const D_HORIZONTAL_MARGIN = 5;

export const POPOVER_SELECTORS =
  "[data-html-popover], [data-html-tooltip], [data-popover], [data-tooltip]";

export function hidePopover() {
  getPopover()
    .fadeOut()
    .remove();

  return getPopover();
}

export function showPopover(event, options = {}) {
  let $enteredElement = $(event.target)
    .closest(POPOVER_SELECTORS)
    .first();

  if (!$enteredElement.length) {
    $enteredElement = $(event.target);
  }

  if (isRetina()) {
    getPopover().addClass("retina");
  }

  if (!getPopover().length) {
    $("body").append($(D_POPOVER_TEMPLATE));
  }

  setPopoverHtmlContent($enteredElement, options.htmlContent);
  setPopoverTextContent($enteredElement, options.textContent);

  getPopover().fadeIn();

  positionPopover($enteredElement);

  return {
    html: content => replaceHtmlContent($enteredElement, content),
    text: content => replaceTextContent($enteredElement, content),
    hide: hidePopover
  };
}

function setPopoverHtmlContent($enteredElement, content) {
  content =
    content ||
    $enteredElement.attr("data-html-popover") ||
    $enteredElement.attr("data-html-tooltip");

  replaceHtmlContent($enteredElement, content);
}

function setPopoverTextContent($enteredElement, content) {
  content =
    content ||
    $enteredElement.attr("data-popover") ||
    $enteredElement.attr("data-tooltip");

  replaceTextContent($enteredElement, content);
}

function replaceTextContent($enteredElement, content) {
  if (content) {
    getPopover()
      .find(".d-popover-content")
      .text(content);
    window.requestAnimationFrame(() => positionPopover($enteredElement));
  }
}

function replaceHtmlContent($enteredElement, content) {
  if (content) {
    getPopover()
      .find(".d-popover-content")
      .html(content);
    window.requestAnimationFrame(() => positionPopover($enteredElement));
  }
}

function positionPopover($element) {
  const $popover = getPopover();
  $popover.removeClass("is-above is-under is-left-aligned is-right-aligned");

  const $dHeader = $(".d-header");
  const windowRect = {
    left: 0,
    top: $dHeader.length ? $dHeader[0].getBoundingClientRect().bottom : 0,
    width: $(window).width(),
    height: $(window).height()
  };

  const popoverRect = {
    width: $popover.width(),
    height: $popover.height(),
    left: null,
    right: null
  };

  if (popoverRect.width > windowRect.width - D_HORIZONTAL_MARGIN * 2) {
    popoverRect.width = windowRect.width - D_HORIZONTAL_MARGIN * 2;
    $popover.width(popoverRect.width);
  }

  const targetRect = $element[0].getBoundingClientRect();
  const underSpace = windowRect.height - targetRect.bottom - D_ARROW_HEIGHT;
  const topSpace = targetRect.top - windowRect.top - D_ARROW_HEIGHT;

  if (
    underSpace > popoverRect.height + D_HORIZONTAL_MARGIN ||
    underSpace > topSpace
  ) {
    $popover
      .css("top", targetRect.bottom + window.pageYOffset + D_ARROW_HEIGHT)
      .addClass("is-under");
  } else {
    $popover
      .css(
        "top",
        targetRect.top +
          window.pageYOffset -
          popoverRect.height -
          D_ARROW_HEIGHT
      )
      .addClass("is-above");
  }

  const leftSpace = targetRect.left + targetRect.width / 2;

  if (siteDir() === "ltr") {
    if (leftSpace > popoverRect.width / 2 + D_HORIZONTAL_MARGIN) {
      popoverRect.left = leftSpace - popoverRect.width / 2;
      $popover.css("left", popoverRect.left);
    } else {
      popoverRect.left = D_HORIZONTAL_MARGIN;
      $popover.css("left", popoverRect.left).addClass("is-left-aligned");
    }
  } else {
    const rightSpace = windowRect.width - targetRect.right;

    if (rightSpace > popoverRect.width / 2 + D_HORIZONTAL_MARGIN) {
      popoverRect.left = leftSpace - popoverRect.width / 2;
      $popover.css("left", popoverRect.left);
    } else {
      popoverRect.left =
        windowRect.width - popoverRect.width - D_HORIZONTAL_MARGIN * 2;
      $popover.css("left", popoverRect.left).addClass("is-right-aligned");
    }
  }

  let arrowPosition;
  if (siteDir() === "ltr") {
    arrowPosition = Math.abs(targetRect.left - popoverRect.left);
  } else {
    arrowPosition = targetRect.left - popoverRect.left + targetRect.width / 2;
  }
  $popover.find(".d-popover-arrow").css("left", arrowPosition);
}

function isRetina() {
  return window.devicePixelRatio && window.devicePixelRatio > 1;
}

function getPopover() {
  return $(document.getElementById(D_POPOVER_ID));
}
