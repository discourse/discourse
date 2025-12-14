import { getBrowserInfo } from "./browser-detection";

/**
 * Parse a CSS dimension value into multiple formats.
 * @param {string} styleValue - CSS value string (e.g., "100px")
 * @returns {{px: string, unitless: number, unitlessRoundedDown: number}}
 */
function parseDimension(styleValue) {
  return {
    px: styleValue,
    unitless: parseFloat(styleValue),
    unitlessRoundedDown: parseInt(styleValue, 10),
  };
}

/**
 * @class DimensionCalculator
 * Calculates and applies CSS dimensions for sheet positioning and scroll behavior.
 * Handles view/content sizing, detent markers, spacers, and snap accelerators.
 */
export default class DimensionCalculator {
  /** @type {Object} */
  elements;

  /**
   * @param {Object} elements - DOM element references
   * @param {HTMLElement} elements.view - The view element
   * @param {HTMLElement} elements.content - The content element
   * @param {HTMLElement[]} elements.detentMarkers - Detent marker elements
   */
  constructor(elements) {
    this.elements = elements;
  }

  /**
   * Calculate all dimensions needed for sheet positioning.
   * @param {string} track - Track direction (bottom, top, left, right, horizontal, vertical)
   * @param {string} contentPlacement - Content placement within the sheet
   * @param {Object} options - Additional options
   * @param {boolean} [options.swipeOutDisabled=false] - Whether swipe out is disabled
   * @param {boolean} [options.edgeAlignedNoOvershoot=false] - Whether edge-aligned with no overshoot
   * @param {number|string|Function} [options.snapOutAcceleration="auto"] - Snap out acceleration
   * @param {number|string} [options.snapToEndDetentsAcceleration="auto"] - Snap to end acceleration
   * @returns {Object} Calculated dimensions object
   */
  calculateDimensions(track, contentPlacement, options = {}) {
    const {
      swipeOutDisabled = false,
      edgeAlignedNoOvershoot = false,
      snapOutAcceleration = "auto",
      snapToEndDetentsAcceleration = "auto",
    } = options;

    const viewElement = this.elements.view;
    const contentElement = this.elements.content;
    const detentMarkers = this.elements.detentMarkers;

    const viewStyle = window.getComputedStyle(viewElement);
    const contentStyle = window.getComputedStyle(contentElement);

    const isHorizontal =
      track === "right" || track === "left" || track === "horizontal";
    const travelProp = isHorizontal ? "width" : "height";
    const crossProp = isHorizontal ? "height" : "width";

    const viewDimensions = {
      travelAxis: parseDimension(viewStyle.getPropertyValue(travelProp)),
      crossAxis: parseDimension(viewStyle.getPropertyValue(crossProp)),
    };

    const contentDimensions = {
      travelAxis: parseDimension(contentStyle.getPropertyValue(travelProp)),
      crossAxis: parseDimension(contentStyle.getPropertyValue(crossProp)),
    };

    const isCenteredTrack = track === "horizontal" || track === "vertical";
    const swipeOutDisabledWithDetent = !isCenteredTrack && swipeOutDisabled;
    const backSpacerEdgeAligned = !isCenteredTrack && edgeAlignedNoOvershoot;

    const useAutoEdgePadding = snapToEndDetentsAcceleration === "auto";
    const frontSpacerEdgePadding =
      swipeOutDisabledWithDetent && useAutoEdgePadding ? 10 : 0;
    const backSpacerEdgePadding =
      backSpacerEdgeAligned && useAutoEdgePadding ? 10 : 0;

    // Pass 1: Apply view/content dimensions so detent markers can resolve CSS variables
    const preliminaryDimensions = {
      view: viewDimensions,
      content: contentDimensions,
      detentMarkers: [],
    };
    this.#applyDimensionVariables(
      preliminaryDimensions,
      viewElement,
      contentPlacement,
      {
        track,
        isCenteredTrack,
        swipeOutDisabledWithDetent,
        frontSpacerEdgePadding,
        backSpacerEdgePadding,
        snapOutAcceleration,
      }
    );

    // Pass 2: Read detent markers (they can now resolve CSS variables)
    // The DOM now contains effectiveDetents (user detents + contentSize)
    // so we always have at least 1 marker rendered.
    let n = 0;
    const contentSize = contentDimensions.travelAxis.unitless;
    const markerCount = detentMarkers.length;

    // Read all markers and accumulate their sizes
    const detentMarkerDimensions = detentMarkers.map((marker, index) => {
      const markerStyle = window.getComputedStyle(marker);
      const dims = {
        travelAxis: parseDimension(markerStyle.getPropertyValue(travelProp)),
        crossAxis: parseDimension(markerStyle.getPropertyValue(crossProp)),
      };

      if (index !== markerCount - 1) {
        n += dims.travelAxis.unitless;
      }

      return {
        ...dims,
        accumulatedOffsets: {
          travelAxis: {
            px: `${n}px`,
            unitless: n,
            unitlessRoundedDown: null,
          },
        },
      };
    });

    if (detentMarkerDimensions.length > 0) {
      const lastIndex = detentMarkerDimensions.length - 1;
      const remainingContentSize = contentSize - n;
      detentMarkerDimensions[lastIndex] = {
        travelAxis: {
          px: `${remainingContentSize}px`,
          unitless: remainingContentSize,
          unitlessRoundedDown: null,
        },
        crossAxis: {
          px: "1px",
          unitless: 1,
          unitlessRoundedDown: 1,
        },
        accumulatedOffsets: {
          travelAxis: {
            px: `${n + remainingContentSize}px`,
            unitless: n + remainingContentSize,
            unitlessRoundedDown: null,
          },
        },
      };
    }

    // Calculate progress values at each detent (start with closed state, progress = 0)
    const createProgressEntry = (baseOffset) => ({
      before: (baseOffset - 2.1) / contentSize,
      exact: baseOffset / contentSize,
      after: (baseOffset + 2.1) / contentSize,
    });

    const progressAtDetents = [createProgressEntry(0)];

    // Add progress entry for each marker EXCEPT the last one.
    // The last marker represents full height, so it doesn't need a separate entry.
    detentMarkerDimensions.slice(0, -1).forEach((marker) => {
      const offset = marker.accumulatedOffsets.travelAxis.unitless;
      progressAtDetents.push(createProgressEntry(offset));
    });

    // Final entry for full height (progress = 1.0)
    progressAtDetents.push(createProgressEntry(contentSize));

    const finalDimensions = {
      view: viewDimensions,
      content: contentDimensions,
      detentMarkers: detentMarkerDimensions,
      progressValueAtDetents: progressAtDetents,
      exactProgressValueAtDetents: progressAtDetents.map((p) => p.exact),
      swipeOutDisabledWithDetent,
      frontSpacerEdgePadding,
      backSpacerEdgePadding,
    };

    // Re-apply with detent markers for front spacer calculation
    this.#applyDimensionVariables(
      finalDimensions,
      viewElement,
      contentPlacement,
      {
        track,
        isCenteredTrack,
        swipeOutDisabledWithDetent,
        frontSpacerEdgePadding,
        backSpacerEdgePadding,
        snapOutAcceleration,
      }
    );

    return finalDimensions;
  }

  /**
   * Set CSS custom properties on the view element.
   * @param {Object} dimensions - The calculated dimensions
   * @param {HTMLElement} viewElement - The view element
   * @param {string} [contentPlacement="end"] - Content placement
   * @param {Object} [options={}] - Additional options
   * @param {string} options.track - Track direction
   * @param {boolean} options.isCenteredTrack - Whether using horizontal/vertical track
   * @param {boolean} [options.swipeOutDisabledWithDetent=false] - Whether swipe out is disabled
   * @param {number} [options.frontSpacerEdgePadding=0] - Front spacer edge padding
   * @param {number} [options.backSpacerEdgePadding=0] - Back spacer edge padding
   * @param {string|number|Function} [options.snapOutAcceleration="auto"] - Snap out acceleration setting
   * @returns {void}
   */
  #applyDimensionVariables(
    dimensions,
    viewElement,
    contentPlacement = "end",
    options = {}
  ) {
    const {
      isCenteredTrack = false,
      swipeOutDisabledWithDetent = false,
      frontSpacerEdgePadding = 0,
      backSpacerEdgePadding = 0,
      snapOutAcceleration = "auto",
    } = options;

    if (dimensions.view) {
      viewElement.style.setProperty(
        "--d-sheet-view-travel-axis",
        dimensions.view.travelAxis.px
      );
      viewElement.style.setProperty(
        "--d-sheet-view-cross-axis",
        dimensions.view.crossAxis.px
      );
    }

    if (dimensions.content) {
      viewElement.style.setProperty(
        "--d-sheet-content-travel-axis",
        dimensions.content.travelAxis.px
      );
      viewElement.style.setProperty(
        "--d-sheet-content-cross-axis",
        dimensions.content.crossAxis.px
      );
    }

    const viewSize = dimensions.view?.travelAxis?.unitless || 0;
    const contentSize = dimensions.content?.travelAxis?.unitless || 0;
    const snapOutAccelerator = this.#calculateSnapOutAccelerator(
      snapOutAcceleration,
      viewSize,
      contentSize,
      contentPlacement
    );

    if (dimensions.view && dimensions.content) {
      let frontSpacerSize;

      if (isCenteredTrack) {
        frontSpacerSize =
          viewSize / 2 +
          viewSize -
          (viewSize - contentSize) / 2 +
          snapOutAccelerator;
      } else if (swipeOutDisabledWithDetent) {
        const firstDetentSize =
          dimensions.detentMarkers?.[0]?.travelAxis?.unitless ?? 0;
        frontSpacerSize =
          contentSize - firstDetentSize + frontSpacerEdgePadding;
      } else if (contentPlacement === "center") {
        frontSpacerSize =
          viewSize - (viewSize - contentSize) / 2 + snapOutAccelerator;
      } else {
        frontSpacerSize = contentSize + snapOutAccelerator;
      }

      dimensions.frontSpacer = {
        travelAxis: {
          px: `${frontSpacerSize}px`,
          unitless: frontSpacerSize,
        },
      };

      viewElement.style.setProperty(
        "--d-sheet-front-spacer",
        `${frontSpacerSize}px`
      );
    }

    if (dimensions.view && dimensions.content) {
      let backSpacerSize;

      if (isCenteredTrack) {
        backSpacerSize =
          viewSize / 2 +
          viewSize -
          (viewSize - contentSize) / 2 +
          snapOutAccelerator;
      } else if (backSpacerEdgePadding > 0) {
        backSpacerSize = viewSize + backSpacerEdgePadding;
      } else {
        backSpacerSize = viewSize;
      }

      viewElement.style.setProperty(
        "--d-sheet-back-spacer",
        `${backSpacerSize}px`
      );
    }

    // First detent size
    if (dimensions.detentMarkers && dimensions.detentMarkers.length > 0) {
      viewElement.style.setProperty(
        "--d-sheet-first-detent-size",
        dimensions.detentMarkers[0].travelAxis.px
      );
    }

    // Snap accelerator
    dimensions.snapOutAccelerator = {
      travelAxis: {
        px: `${snapOutAccelerator}px`,
        unitless: snapOutAccelerator,
      },
    };

    viewElement.style.setProperty(
      "--d-sheet-snap-accelerator",
      `${snapOutAccelerator}px`
    );
  }

  /**
   * Calculate snap out accelerator value for scroll-snap behavior.
   * @param {string|number|Function} snapOutAcceleration - Acceleration setting
   * @param {number} viewSize - View size in pixels
   * @param {number} contentSize - Content size in pixels
   * @param {string} [contentPlacement="end"] - Content placement
   * @returns {number} Snap accelerator value in pixels
   */
  #calculateSnapOutAccelerator(
    snapOutAcceleration,
    viewSize,
    contentSize,
    contentPlacement = "end"
  ) {
    if (snapOutAcceleration === "auto") {
      const effectiveSize =
        contentPlacement === "center"
          ? contentSize + (viewSize - contentSize) / 2
          : contentSize;

      const { browserEngine, platform } = getBrowserInfo();

      if (browserEngine === "chromium") {
        return effectiveSize <= 1440
          ? 70 + 0.25 * effectiveSize
          : 0.3 * effectiveSize;
      }

      if (browserEngine === "webkit") {
        if (platform === "ios" || platform === "ipados") {
          return effectiveSize <= 716
            ? 15 + 0.1 * effectiveSize
            : 0.12 * effectiveSize;
        }
        return 0.5 * effectiveSize;
      }

      // Gecko (Firefox) or unknown
      return 10;
    }

    if (typeof snapOutAcceleration === "function") {
      const result = parseInt(snapOutAcceleration(contentSize), 10);
      return result < 1
        ? 1
        : result > contentSize / 2
          ? contentSize / 2
          : result;
    }

    if (snapOutAcceleration === "initial") {
      return 1;
    }

    return undefined;
  }
}
