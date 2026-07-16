// Workarounds for the DOM that Zoom's embedded (component view) SDK renders
// into our app root. Everything in here reaches into Zoom's internal MUI
// markup, which the SDK offers no supported hooks for, so all of it is flaky
// by nature if the SDK changes.

const VIDEO_ASPECT_RATIO = 16 / 9;
const MIN_VIDEO_WIDTH = 240;
const MAX_VIDEO_WIDTH = 1440;
const MIN_VIDEO_HEIGHT = 135;
const MAX_VIDEO_HEIGHT = 810;

export function computeZoomViewSize(root) {
  const width = Math.max(
    MIN_VIDEO_WIDTH,
    Math.min(
      MAX_VIDEO_WIDTH,
      Math.floor(root?.getBoundingClientRect().width || 0)
    )
  );

  const height = Math.max(
    MIN_VIDEO_HEIGHT,
    Math.min(MAX_VIDEO_HEIGHT, Math.floor(width / VIDEO_ASPECT_RATIO))
  );

  return { width, height };
}

// `title` is Zoom's translated `toolbar_leave` string, stable only because
// the component view is pinned to en-US when it is initialized. The button
// carries no
// other distinguishing attribute.
export function isZoomLeaveButtonClick(event) {
  return event.target.closest("button.zoom-MuiButton-root")?.title === "Leave";
}

function setInlineStyleValue(element, property, value) {
  if (!element || element.style[property] === value) {
    return;
  }

  element.style[property] = value;
}

function setInlineHeight(element, height) {
  setInlineStyleValue(element, "height", `${height}px`);
}

export function syncZoomLayout(root) {
  if (!root) {
    return;
  }

  const widget = root.querySelector(
    '[role="region"][aria-label="Zoom Web SDK Widget"]'
  );
  const widgetHeight = Math.ceil(widget?.getBoundingClientRect().height || 0);

  if (widgetHeight > 0) {
    setInlineHeight(root, widgetHeight);
  }

  const playerContainers = root.querySelectorAll("video-player-container");
  const galleryPanel = root.querySelector(
    '[id^="suspension-view-tabpanel-gallery"]'
  );

  if (!galleryPanel || playerContainers.length !== 1) {
    return;
  }

  const player = playerContainers[0];
  const playerWrapper = player.parentElement;
  const gridWrapper = playerWrapper?.parentElement;
  const innerPaper = galleryPanel.parentElement;
  const outerPaper = innerPaper?.parentElement;
  const resizable = outerPaper?.parentElement;
  const absoluteBox = resizable?.parentElement;
  const toolbar = innerPaper?.querySelector(".zoom-MuiToolbar-root");
  const footer = Array.from(outerPaper?.children || []).find(
    (element) => element !== innerPaper
  );

  const playerHeight = Math.ceil(player.getBoundingClientRect().height || 0);
  const toolbarHeight = Math.ceil(toolbar?.getBoundingClientRect().height || 0);
  const footerHeight = Math.ceil(footer?.getBoundingClientRect().height || 0);
  const innerHeight = toolbarHeight + playerHeight;
  const outerHeight = innerHeight + footerHeight + 4;

  if (!playerHeight || !innerHeight || !outerHeight) {
    return;
  }

  // Zoom's component view currently centers a single tile inside the
  // gallery-limited panel. Collapse that wrapper so the lone presenter tile
  // sits directly below the toolbar instead of midway down the component view.
  setInlineStyleValue(player, "top", "0px");
  setInlineStyleValue(player, "bottom", "auto");

  [playerWrapper, gridWrapper, galleryPanel].forEach((element) => {
    setInlineHeight(element, playerHeight);
  });

  setInlineHeight(innerPaper, innerHeight);
  [outerPaper, resizable, absoluteBox, root].forEach((element) => {
    setInlineHeight(element, outerHeight);
  });
}
