import { getBrowserInfo } from "./browser-detection";

/**
 * @class SheetDimensionCalculator
 * Calculates and applies CSS dimensions for sheet positioning and scroll behavior.
 * Handles view/content sizing, detent markers, spacers, and snap accelerators.
 */
export default class SheetDimensionCalculator {
  /** @type {Object} */
  elements;

  /** @type {Object} */
  cache = {};

  /** @type {string|number|Function} */
  snapOutAcceleration = "auto";

  /** @type {string|number} */
  snapToEndDetentsAcceleration = "auto";

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

    this.snapOutAcceleration = snapOutAcceleration;
    this.snapToEndDetentsAcceleration = snapToEndDetentsAcceleration;

    const viewElement = this.elements.view;
    const contentElement = this.elements.content;
    const detentMarkers = this.elements.detentMarkers;

    const viewStyle = window.getComputedStyle(viewElement);
    const contentStyle = window.getComputedStyle(contentElement);

    const isHorizontal =
      track === "right" || track === "left" || track === "horizontal";
    const travelProp = isHorizontal ? "width" : "height";
    const crossProp = isHorizontal ? "height" : "width";

    const parseDimension = (styleValue) => ({
      px: styleValue,
      unitless: parseFloat(styleValue),
      unitlessRoundedDown: parseInt(styleValue, 10),
    });

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
    this.applyDimensionVariables(
      preliminaryDimensions,
      viewElement,
      contentPlacement,
      {
        track,
        swipeOutDisabledWithDetent,
        frontSpacerEdgePadding,
        backSpacerEdgePadding,
      }
    );

    // Pass 2: Read detent markers (they can now resolve CSS variables)
    // The DOM now contains effectiveDetents (user detents + contentSize)
    // so we always have at least 1 marker rendered.
    let n = 0;
    const contentSize = contentDimensions.travelAxis.unitless;

    // Read all markers and accumulate their sizes
    const detentMarkerDimensions = detentMarkers.map((marker) => {
      const markerStyle = window.getComputedStyle(marker);
      const dims = {
        travelAxis: parseDimension(markerStyle.getPropertyValue(travelProp)),
        crossAxis: parseDimension(markerStyle.getPropertyValue(crossProp)),
      };

      n += dims.travelAxis.unitless;

      return {
        ...dims,
        accumulatedOffsets: {
          travelAxis: {
            px: `${n}px`,
            unitless: n,
            unitlessRoundedDown: null,
          },
        },
        cumulativeSize: n,
      };
    });

    // Calculate progress values at each detent (start with closed state, progress = 0)
    const progressAtDetents = [
      {
        before: -2.1 / contentSize,
        exact: 0,
        after: 2.1 / contentSize,
      },
    ];

    // Add progress entry for each marker EXCEPT the last one.
    // The last marker represents full height, so it doesn't need a separate entry.
    detentMarkerDimensions.slice(0, -1).forEach((marker) => {
      const offset = marker.accumulatedOffsets.travelAxis.unitless;
      progressAtDetents.push({
        before: (offset - 2.1) / contentSize,
        exact: offset / contentSize,
        after: (offset + 2.1) / contentSize,
      });
    });

    // Final entry for full height (progress = 1.0)
    progressAtDetents.push({
      before: (contentSize - 2.1) / contentSize,
      exact: 1,
      after: (contentSize + 2.1) / contentSize,
    });

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
    this.applyDimensionVariables(
      finalDimensions,
      viewElement,
      contentPlacement,
      {
        track,
        swipeOutDisabledWithDetent,
        frontSpacerEdgePadding,
        backSpacerEdgePadding,
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
   * @param {boolean} [options.swipeOutDisabledWithDetent=false] - Whether swipe out is disabled
   * @param {number} [options.frontSpacerEdgePadding=0] - Front spacer edge padding
   * @param {number} [options.backSpacerEdgePadding=0] - Back spacer edge padding
   * @returns {void}
   */
  applyDimensionVariables(
    dimensions,
    viewElement,
    contentPlacement = "end",
    options = {}
  ) {
    const {
      track,
      swipeOutDisabledWithDetent = false,
      frontSpacerEdgePadding = 0,
      backSpacerEdgePadding = 0,
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

    // Front spacer calculation
    if (dimensions.view && dimensions.content) {
      const viewSize = dimensions.view.travelAxis.unitless;
      const contentSize = dimensions.content.travelAxis.unitless;
      const snapOutAccelerator = this.calculateSnapOutAccelerator(
        viewSize,
        contentSize,
        contentPlacement
      );

      let frontSpacerSize;
      const isCenteredTrack = track === "horizontal" || track === "vertical";

      if (isCenteredTrack) {
        frontSpacerSize = 0;
      } else if (swipeOutDisabledWithDetent) {
        const firstDetentSize =
          dimensions.detentMarkers?.[0]?.travelAxis?.unitless ?? 0;
        frontSpacerSize =
          contentSize - firstDetentSize + frontSpacerEdgePadding;
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

    // Back spacer calculation
    if (dimensions.view && dimensions.content) {
      let backSpacerSize;
      const viewSize = dimensions.view.travelAxis.unitless;
      const isCenteredTrack = track === "horizontal" || track === "vertical";

      if (isCenteredTrack) {
        backSpacerSize = 0;
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
    const snapAcceleratorValue = this.calculateSnapOutAccelerator(
      dimensions.view?.travelAxis?.unitless || 0,
      dimensions.content?.travelAxis?.unitless || 0,
      contentPlacement
    );
    dimensions.snapOutAccelerator = {
      travelAxis: {
        px: `${snapAcceleratorValue}px`,
        unitless: snapAcceleratorValue,
      },
    };

    viewElement.style.setProperty(
      "--d-sheet-snap-accelerator",
      `${snapAcceleratorValue}px`
    );
  }

  /**
   * Calculate snap out accelerator value for scroll-snap behavior.
   * @param {number} viewSize - View size in pixels
   * @param {number} contentSize - Content size in pixels
   * @param {string} [contentPlacement="end"] - Content placement
   * @returns {number} Snap accelerator value in pixels
   */
  calculateSnapOutAccelerator(viewSize, contentSize, contentPlacement = "end") {
    // Numeric mode: use value directly
    if (
      typeof this.snapOutAcceleration === "number" &&
      !Number.isNaN(this.snapOutAcceleration)
    ) {
      return this.snapOutAcceleration;
    }

    // Initial mode: fixed value of 1
    if (this.snapOutAcceleration === "initial") {
      return 1;
    }

    // Function mode: call function and clamp result
    if (typeof this.snapOutAcceleration === "function") {
      const result = parseInt(this.snapOutAcceleration(contentSize), 10);
      return Math.max(1, Math.min(result, contentSize / 2));
    }

    // Auto mode: browser-specific calculation
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
}
