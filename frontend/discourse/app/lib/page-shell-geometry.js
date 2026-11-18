/**
 * Mirrors the page shell's column formulas in `page-shell.scss`, so a drag can
 * map pointer movement to a panel width. The stylesheet stays authoritative;
 * keep the two in step (an integration test compares them).
 */

/**
 * @typedef {object} PanelGeometry
 * @property {"open"|"rail"|"hidden"} mode
 * @property {number} width - Preferred expanded width.
 * @property {number} maxWidth - The panel's own cap.
 * @property {number} referenceWidth - Expanded width the "content" resize
 *   policy reserves in a centered shell.
 * @property {boolean} forcedHidden - Removed by the viewport or constraints.
 *
 * @typedef {object} ShellGeometry
 * @property {"centered"|"full"} width - Shell width policy.
 * @property {"grow"|"content"} resize - Whether a growing panel widens a
 *   centered shell or takes the space from Main.
 * @property {number} viewportWidth - What `100vw` resolves to.
 * @property {number} shellWidth - The shell's own inline size.
 * @property {number} mainMaxWidth - Main's maximum track, content plus padding.
 * @property {number} mainMinWidth
 * @property {number} composerWidth
 * @property {number} railWidth
 * @property {PanelGeometry} navigation
 * @property {PanelGeometry} context
 */

function panelTrack(panel, railWidth, available) {
  if (panel.forcedHidden || panel.mode === "hidden") {
    return 0;
  }
  const room = Math.max(0, available);
  return panel.mode === "rail"
    ? Math.min(railWidth, room)
    : Math.min(panel.maxWidth, panel.width, room);
}

function referenceTrack(panel, railWidth) {
  if (panel.forcedHidden || panel.mode === "hidden") {
    return 0;
  }
  return panel.mode === "rail" ? railWidth : panel.referenceWidth;
}

/**
 * Resolves the shell's six column tracks.
 *
 * @param {ShellGeometry} geometry
 * @returns {{ offset: number, navigation: number, main: number, composer: number, context: number, end: number }}
 */
export function shellTracks(geometry) {
  const {
    shellWidth,
    mainMinWidth,
    mainMaxWidth,
    composerWidth: composer,
    railWidth,
  } = geometry;
  const navigation = panelTrack(
    geometry.navigation,
    railWidth,
    shellWidth - mainMinWidth - composer
  );
  const context = panelTrack(
    geometry.context,
    railWidth,
    shellWidth - navigation - composer - mainMinWidth
  );
  const fixed = navigation + composer + context;

  if (geometry.width === "full") {
    return {
      offset: 0,
      navigation,
      context,
      main: Math.max(0, shellWidth - fixed),
      composer,
      end: 0,
    };
  }

  let maxInlineSize = mainMaxWidth + fixed;
  let mainLimit = mainMaxWidth;
  if (geometry.resize === "content") {
    // The frame keeps its reference size until Main reaches its minimum.
    maxInlineSize = Math.max(
      mainMaxWidth +
        referenceTrack(geometry.navigation, railWidth) +
        referenceTrack(geometry.context, railWidth) +
        composer,
      fixed + mainMinWidth
    );
    mainLimit = maxInlineSize - fixed;
  }

  const offset = Math.max(
    0,
    Math.min(
      (geometry.viewportWidth - maxInlineSize) / 2,
      shellWidth - fixed - mainMinWidth
    )
  );
  const free = Math.max(0, shellWidth - offset - fixed);
  const main = Math.min(mainLimit, free);
  return { offset, navigation, context, main, composer, end: free - main };
}

/**
 * Distance from a panel's own shell edge to its resize handle.
 *
 * @param {ShellGeometry} geometry
 * @param {"navigation"|"context"} panel
 * @returns {number}
 */
export function handleOffset(geometry, panel) {
  const tracks = shellTracks(geometry);
  return (
    tracks.offset +
    tracks.navigation +
    (panel === "context" ? tracks.context : 0)
  );
}

/**
 * Finds the panel width that puts its handle at `targetOffset`. The handle
 * offset never decreases as the panel grows, so a bisection settles it.
 *
 * @param {ShellGeometry} geometry
 * @param {"navigation"|"context"} panel
 * @param {number} targetOffset - Wanted distance from the panel's shell edge.
 * @param {number} minWidth
 * @param {number} maxWidth
 * @returns {number} A whole-pixel width within the bounds.
 */
export function widthForHandleOffset(
  geometry,
  panel,
  targetOffset,
  minWidth,
  maxWidth
) {
  const offsetAt = (width) =>
    handleOffset(
      { ...geometry, [panel]: { ...geometry[panel], width } },
      panel
    );

  let low = minWidth;
  let high = Math.max(minWidth, maxWidth);
  if (offsetAt(high) <= targetOffset) {
    return Math.round(high);
  }
  if (offsetAt(low) >= targetOffset) {
    return Math.round(low);
  }
  while (high - low > 0.5) {
    const middle = (low + high) / 2;
    if (offsetAt(middle) < targetOffset) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return Math.round((low + high) / 2);
}

/**
 * Reads the inputs of {@link shellTracks} from a rendered shell.
 *
 * @param {HTMLElement} shell - The `.page-shell` element.
 * @param {{ navigationWidth: number, contextWidth: number }} state - Panel
 *   width preferences, as held by the page shell service.
 * @returns {ShellGeometry}
 */
export function readShellGeometry(shell, state) {
  const styles = getComputedStyle(shell);
  const pixels = (name) => parseFloat(styles.getPropertyValue(name)) || 0;
  const tracks = styles.gridTemplateColumns.split(" ").map(parseFloat);
  const content = shell.querySelector(".page-shell__main-content");
  // The stylesheet removes a track with `display: none`; a panel that has
  // not rendered still has its track.
  const isHidden = (selector) => {
    const element = shell.querySelector(selector);
    return !!element && getComputedStyle(element).display === "none";
  };

  return {
    width: shell.dataset.width,
    resize: shell.dataset.resize,
    viewportWidth: window.innerWidth,
    shellWidth: shell.clientWidth,
    mainMaxWidth: content ? parseFloat(getComputedStyle(content).maxWidth) : 0,
    mainMinWidth: pixels("--_page-shell-content-min-width"),
    composerWidth: tracks[4] || 0,
    railWidth: pixels("--_page-shell-panel-rail-width"),
    navigation: {
      mode: shell.dataset.navigation,
      width: state.navigationWidth,
      maxWidth: pixels("--_page-shell-navigation-max-width"),
      referenceWidth: pixels("--_page-shell-navigation-default-width"),
      forcedHidden: isHidden(".page-shell__navigation"),
    },
    context: {
      mode: shell.dataset.context,
      width: state.contextWidth,
      maxWidth: pixels("--_page-shell-context-max-width"),
      referenceWidth: pixels("--_page-shell-context-default-width"),
      forcedHidden:
        shell.hasAttribute("data-constrained-context") ||
        isHidden(".page-shell__context"),
    },
  };
}
