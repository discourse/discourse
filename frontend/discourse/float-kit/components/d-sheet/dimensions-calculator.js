/**
 * Core dimension calculation engine for d-sheet components. Computes all sizing, spacing,
 * and scroll physics for drawer/sheet UI patterns across different tracks (left/right/top/bottom/horizontal/vertical).
 * Handles detent markers (snap points), spacers (front/back padding for scroll physics),
 * snap-out accelerators (browser-specific momentum tuning), and progress tracking at detent boundaries.
 * Supports centered tracks, edge-aligned sheets, swipe-out gestures, and WebKit-specific optimizations.
 */

import { capabilities } from "discourse/services/capabilities";

/**
 * Tolerance value for progress calculations near detent boundaries.
 * @type {number}
 */
const PROGRESS_TOLERANCE = 2.1;

/**
 * Default edge padding applied when using "auto" snap acceleration.
 * @type {number}
 */
const AUTO_EDGE_PADDING = 10;

/**
 * Chromium browser threshold for snap accelerator calculation.
 * @type {number}
 */
const CHROMIUM_THRESHOLD = 1440;

/**
 * WebKit mobile (iOS/iPadOS) threshold for snap accelerator calculation.
 * @type {number}
 */
const WEBKIT_MOBILE_THRESHOLD = 716;

/**
 * @typedef {Object} DimensionValue
 * @property {string} px - The size as a CSS pixel string (e.g. "100px").
 * @property {number} unitless - The raw numeric size.
 * @property {number} unitlessRoundedDown - The size rounded down to an integer.
 */

/**
 * @typedef {Object} AxisDimensions
 * @property {DimensionValue} travelAxis - Dimension along the travel (scroll) axis.
 * @property {DimensionValue} crossAxis - Dimension along the perpendicular axis.
 */

/**
 * @typedef {Object} DetentMarkerDimension
 * @property {DimensionValue} travelAxis - Travel axis dimension for this marker.
 * @property {DimensionValue} crossAxis - Cross axis dimension for this marker.
 * @property {{ travelAxis: DimensionValue }} accumulatedOffsets - Cumulative offsets from preceding markers.
 */

/**
 * @typedef {Object} ProgressEntry
 * @property {number} before - Progress value just before the detent boundary.
 * @property {number} exact - Exact progress value at the detent boundary.
 * @property {number} after - Progress value just after the detent boundary.
 */

/**
 * @typedef {Object} SheetDimensions
 * @property {AxisDimensions} view - Dimensions of the view element.
 * @property {AxisDimensions} scroll - Dimensions of the scroll viewport.
 * @property {AxisDimensions} content - Dimensions of the content element.
 * @property {DetentMarkerDimension[]} detentMarkers - Computed dimensions for each detent marker.
 * @property {ProgressEntry[]} [progressValueAtDetents] - Progress entries at each detent.
 * @property {number[]} [exactProgressValueAtDetents] - Exact progress values at each detent.
 * @property {{ travelAxis: DimensionValue }} [frontSpacer] - Front spacer dimension.
 * @property {{ travelAxis: DimensionValue }} [backSpacer] - Back spacer dimension.
 * @property {{ travelAxis: DimensionValue }} [snapOutAccelerator] - Snap-out accelerator dimension.
 */

/**
 * @typedef {Object} CalculatorElements
 * @property {HTMLElement} view - The sheet view container element.
 * @property {HTMLElement} content - The sheet content element.
 * @property {HTMLElement} scrollContainer - The scrollable container element.
 * @property {HTMLElement[]} detentMarkers - The detent marker elements.
 */

/**
 * @typedef {Object} DimensionOptions
 * @property {boolean} [swipeOutDisabledWithDetent] - Whether swipe-out is disabled when a detent is active.
 * @property {boolean} [edgeAlignedNoOvershoot] - Whether edge-aligned sheets prevent overshoot.
 * @property {string | number | ((contentSize: number) => number)} [snapOutAcceleration] - Snap-out acceleration strategy or value.
 * @property {string} [snapToEndDetentsAcceleration] - Snap-to-end detent acceleration strategy.
 * @property {boolean} [webkitSmallSpacerMode] - Whether to use minimal spacer sizes for WebKit.
 */

/**
 * @typedef {Object} BuildContext
 * @property {string} track - The track direction.
 * @property {string} contentPlacement - Where the content is placed within the view.
 * @property {boolean} isHorizontal - Whether the track is horizontal.
 * @property {boolean} isCenteredTrack - Whether the track is a centered (symmetric) track.
 * @property {string} travelProp - CSS property name for the travel axis ("width" or "height").
 * @property {string} crossProp - CSS property name for the cross axis ("height" or "width").
 * @property {boolean} swipeOutDisabledWithDetent - Whether swipe-out is disabled with a detent.
 * @property {number} frontSpacerEdgePadding - Edge padding for the front spacer.
 * @property {number} backSpacerEdgePadding - Edge padding for the back spacer.
 * @property {string | number | ((contentSize: number) => number)} snapOutAcceleration - Snap-out acceleration value.
 * @property {boolean} webkitSmallSpacerMode - Whether to use minimal spacer sizes for WebKit.
 */

/**
 * Extracts travel and cross axis dimensions from a computed style.
 *
 * @param {CSSStyleDeclaration} computedStyle - The computed style of an element.
 * @param {string} travelProp - CSS property name for the travel axis.
 * @param {string} crossProp - CSS property name for the cross axis.
 * @returns {AxisDimensions} The parsed axis dimensions.
 */
function parseDimensionsFromStyle(computedStyle, travelProp, crossProp) {
  const travelValue = computedStyle.getPropertyValue(travelProp);
  const crossValue = computedStyle.getPropertyValue(crossProp);

  return {
    travelAxis: {
      px: travelValue,
      unitless: parseFloat(travelValue),
      unitlessRoundedDown: parseInt(travelValue, 10),
    },
    crossAxis: {
      px: crossValue,
      unitless: parseFloat(crossValue),
      unitlessRoundedDown: parseInt(crossValue, 10),
    },
  };
}

/**
 * Creates a dimension value object from a numeric size.
 *
 * @param {number} size - The numeric size in pixels.
 * @returns {DimensionValue} The dimension value with px string, unitless, and rounded forms.
 */
function createDimensionValue(size) {
  return {
    px: `${size}px`,
    unitless: size,
    unitlessRoundedDown: Math.floor(size),
  };
}

/**
 * Handles view/content sizing, detent markers, and spacers.
 */
export default class DimensionCalculator {
  /**
   * References to the DOM elements used for dimension calculations.
   * @type {CalculatorElements}
   */
  elements;

  /**
   * @param {CalculatorElements} elements - The DOM elements to measure.
   */
  constructor(elements) {
    this.elements = elements;
  }

  /**
   * Computes all sheet dimensions including spacers, detents, and progress values.
   *
   * @param {string} track - The track direction (e.g. "left", "right", "horizontal", "vertical").
   * @param {string} contentPlacement - Where the content sits within the view (e.g. "end", "center").
   * @param {DimensionOptions} [options] - Additional calculation options.
   * @returns {SheetDimensions} The fully computed sheet dimensions.
   */
  calculateDimensions(track, contentPlacement, options = {}) {
    const context = this.#buildContext(track, contentPlacement, options);
    const dimensions = this.#parseInitialDimensions(context);

    this.#applyVariables(dimensions, context);

    const detents = this.#calculateDetents(dimensions, context);
    Object.assign(dimensions, detents);

    this.#applyVariables(dimensions, context);

    return dimensions;
  }

  /**
   * Builds the internal context object from track, placement, and options.
   *
   * @param {string} track - The track direction.
   * @param {string} contentPlacement - Where the content is placed.
   * @param {DimensionOptions} options - Calculation options.
   * @returns {BuildContext} The resolved context for dimension calculations.
   */
  #buildContext(track, contentPlacement, options) {
    const isHorizontal =
      track === "right" || track === "left" || track === "horizontal";
    const isCenteredTrack = track === "horizontal" || track === "vertical";

    const {
      swipeOutDisabledWithDetent = false,
      edgeAlignedNoOvershoot = false,
      snapOutAcceleration = "auto",
      snapToEndDetentsAcceleration = "auto",
      webkitSmallSpacerMode = false,
    } = options;

    const useAutoEdgePadding = snapToEndDetentsAcceleration === "auto";

    return {
      track,
      contentPlacement,
      isHorizontal,
      isCenteredTrack,
      travelProp: isHorizontal ? "width" : "height",
      crossProp: isHorizontal ? "height" : "width",
      swipeOutDisabledWithDetent:
        !isCenteredTrack && swipeOutDisabledWithDetent,
      frontSpacerEdgePadding:
        !isCenteredTrack && swipeOutDisabledWithDetent && useAutoEdgePadding
          ? AUTO_EDGE_PADDING
          : 0,
      backSpacerEdgePadding:
        edgeAlignedNoOvershoot && useAutoEdgePadding ? AUTO_EDGE_PADDING : 0,
      snapOutAcceleration,
      webkitSmallSpacerMode,
    };
  }

  /**
   * Parses initial view and content dimensions from the DOM.
   *
   * @param {BuildContext} context - The calculation context.
   * @returns {SheetDimensions} Initial dimensions with empty detent markers.
   */
  #parseInitialDimensions(context) {
    const { view, content } = this.elements;
    const { travelProp, crossProp } = context;
    const viewDimensions = parseDimensionsFromStyle(
      window.getComputedStyle(view),
      travelProp,
      crossProp
    );

    return {
      view: viewDimensions,
      scroll: viewDimensions,
      content: parseDimensionsFromStyle(
        window.getComputedStyle(content),
        travelProp,
        crossProp
      ),
      detentMarkers: [],
    };
  }

  /**
   * Calculates detent marker dimensions and progress values at each detent.
   *
   * @param {SheetDimensions} dimensions - The current dimensions state.
   * @param {BuildContext} context - The calculation context.
   * @returns {{ detentMarkers: DetentMarkerDimension[], progressValueAtDetents: ProgressEntry[], exactProgressValueAtDetents: number[] }} Detent-related dimension data.
   */
  #calculateDetents(dimensions, context) {
    const { detentMarkers } = this.elements;
    const { travelProp, crossProp } = context;
    const contentSize = dimensions.content.travelAxis.unitless;

    const detentMarkerDimensions = this.#calculateDetentMarkerDimensions(
      detentMarkers,
      travelProp,
      crossProp,
      contentSize
    );

    const progressAtDetents = this.#calculateProgressAtDetents(
      detentMarkerDimensions,
      contentSize
    );

    return {
      detentMarkers: detentMarkerDimensions,
      progressValueAtDetents: progressAtDetents,
      exactProgressValueAtDetents: progressAtDetents.map((p) => p.exact),
    };
  }

  /**
   * Computes dimensions and accumulated offsets for each detent marker element.
   *
   * @param {HTMLElement[]} markers - The detent marker DOM elements.
   * @param {string} travelProp - CSS property for the travel axis.
   * @param {string} crossProp - CSS property for the cross axis.
   * @param {number} contentSize - The total content size along the travel axis.
   * @returns {DetentMarkerDimension[]} Dimensions for each detent marker with accumulated offsets.
   */
  #calculateDetentMarkerDimensions(
    markers,
    travelProp,
    crossProp,
    contentSize
  ) {
    let accumulatedOffset = 0;
    const markerCount = markers.length;

    const dimensions = markers.map((marker, index) => {
      const dims = parseDimensionsFromStyle(
        window.getComputedStyle(marker),
        travelProp,
        crossProp
      );

      if (index !== markerCount - 1) {
        accumulatedOffset += dims.travelAxis.unitless;
      }

      return {
        ...dims,
        accumulatedOffsets: {
          travelAxis: createDimensionValue(accumulatedOffset),
        },
      };
    });

    if (dimensions.length > 0) {
      const lastIndex = dimensions.length - 1;
      const remainingContentSize = contentSize - accumulatedOffset;

      dimensions[lastIndex] = {
        travelAxis: createDimensionValue(remainingContentSize),
        crossAxis: createDimensionValue(1),
        accumulatedOffsets: {
          travelAxis: createDimensionValue(
            accumulatedOffset + remainingContentSize
          ),
        },
      };
    }

    return dimensions;
  }

  /**
   * Calculates progress values (before, exact, after) at each detent boundary.
   *
   * @param {DetentMarkerDimension[]} detentMarkerDimensions - The computed marker dimensions.
   * @param {number} contentSize - The total content size along the travel axis.
   * @returns {ProgressEntry[]} Progress entries for start, each intermediate detent, and end.
   */
  #calculateProgressAtDetents(detentMarkerDimensions, contentSize) {
    const createProgressEntry = (baseOffset) => ({
      before: (baseOffset - PROGRESS_TOLERANCE) / contentSize,
      exact: baseOffset / contentSize,
      after: (baseOffset + PROGRESS_TOLERANCE) / contentSize,
    });

    const progressAtDetents = [createProgressEntry(0)];

    detentMarkerDimensions.slice(0, -1).forEach((marker) => {
      const offset = marker.accumulatedOffsets.travelAxis.unitless;
      progressAtDetents.push(createProgressEntry(offset));
    });

    progressAtDetents.push(createProgressEntry(contentSize));

    return progressAtDetents;
  }

  /**
   * Applies computed CSS custom properties and spacer dimensions to the view element.
   *
   * @param {SheetDimensions} dimensions - The current dimensions state (mutated in place).
   * @param {BuildContext} context - The calculation context.
   */
  #applyVariables(dimensions, context) {
    const { view: viewElement } = this.elements;
    const {
      contentPlacement,
      isCenteredTrack,
      swipeOutDisabledWithDetent,
      frontSpacerEdgePadding,
      backSpacerEdgePadding,
      snapOutAcceleration,
      webkitSmallSpacerMode,
    } = context;

    this.#applyViewContentStyles(dimensions, viewElement);

    const viewSize = dimensions.view.travelAxis.unitless;
    const contentSize = dimensions.content.travelAxis.unitless;

    const snapOutAccelerator = this.#calculateSnapOutAccelerator(
      snapOutAcceleration,
      viewSize,
      contentSize,
      contentPlacement
    );

    const frontSpacerSize = this.#calculateFrontSpacerSize(
      viewSize,
      contentSize,
      snapOutAccelerator,
      dimensions.detentMarkers,
      {
        isCenteredTrack,
        swipeOutDisabledWithDetent,
        frontSpacerEdgePadding,
        contentPlacement,
        webkitSmallSpacerMode,
      }
    );

    dimensions.frontSpacer = {
      travelAxis: createDimensionValue(frontSpacerSize),
    };

    const backSpacerSize = this.#calculateBackSpacerSize(
      viewSize,
      contentSize,
      snapOutAccelerator,
      { isCenteredTrack, backSpacerEdgePadding, webkitSmallSpacerMode }
    );

    dimensions.backSpacer = {
      travelAxis: createDimensionValue(backSpacerSize),
    };

    viewElement.style.setProperty(
      "--d-sheet-front-spacer",
      `${frontSpacerSize}px`
    );

    viewElement.style.setProperty(
      "--d-sheet-back-spacer",
      `${backSpacerSize}px`
    );

    this.#applyDetentAcceleratorStyles(
      dimensions,
      viewElement,
      snapOutAccelerator
    );
  }

  /**
   * Sets CSS custom properties for view and content axis sizes on the view element.
   *
   * @param {SheetDimensions} dimensions - The current dimensions state.
   * @param {HTMLElement} viewElement - The view DOM element to apply styles to.
   */
  #applyViewContentStyles(dimensions, viewElement) {
    viewElement.style.setProperty(
      "--d-sheet-view-travel-axis",
      dimensions.view.travelAxis.px
    );
    viewElement.style.setProperty(
      "--d-sheet-view-cross-axis",
      dimensions.view.crossAxis.px
    );
    viewElement.style.setProperty(
      "--d-sheet-content-travel-axis",
      dimensions.content.travelAxis.px
    );
    viewElement.style.setProperty(
      "--d-sheet-content-cross-axis",
      dimensions.content.crossAxis.px
    );
  }

  /**
   * Applies the first detent size and snap accelerator as CSS custom properties.
   *
   * @param {SheetDimensions} dimensions - The current dimensions state (mutated to add snapOutAccelerator).
   * @param {HTMLElement} viewElement - The view DOM element to apply styles to.
   * @param {number} snapOutAccelerator - The computed snap-out accelerator value in pixels.
   */
  #applyDetentAcceleratorStyles(dimensions, viewElement, snapOutAccelerator) {
    if (dimensions.detentMarkers?.length > 0) {
      viewElement.style.setProperty(
        "--d-sheet-first-detent-size",
        dimensions.detentMarkers[0].travelAxis.px
      );
    }

    dimensions.snapOutAccelerator = {
      travelAxis: createDimensionValue(snapOutAccelerator),
    };

    viewElement.style.setProperty(
      "--d-sheet-snap-accelerator",
      `${snapOutAccelerator}px`
    );
  }

  /**
   * Calculates the front spacer size based on track type and layout configuration.
   *
   * @param {number} viewSize - The view size along the travel axis.
   * @param {number} contentSize - The content size along the travel axis.
   * @param {number} snapOutAccelerator - The snap-out accelerator value.
   * @param {DetentMarkerDimension[]} detentMarkers - The detent marker dimensions.
   * @param {{ isCenteredTrack: boolean, swipeOutDisabledWithDetent: boolean, frontSpacerEdgePadding: number, contentPlacement: string, webkitSmallSpacerMode: boolean }} options - Layout options.
   * @returns {number} The front spacer size in pixels.
   */
  #calculateFrontSpacerSize(
    viewSize,
    contentSize,
    snapOutAccelerator,
    detentMarkers,
    options
  ) {
    const {
      isCenteredTrack,
      swipeOutDisabledWithDetent,
      frontSpacerEdgePadding,
      contentPlacement,
      webkitSmallSpacerMode,
    } = options;

    if (webkitSmallSpacerMode) {
      return isCenteredTrack ? viewSize / 2 + 1 : 1;
    }

    if (isCenteredTrack) {
      return (
        viewSize / 2 +
        viewSize -
        (viewSize - contentSize) / 2 +
        snapOutAccelerator
      );
    }

    if (swipeOutDisabledWithDetent) {
      const firstDetentSize = detentMarkers?.[0]?.travelAxis?.unitless ?? 0;
      return contentSize - firstDetentSize + frontSpacerEdgePadding;
    }

    if (contentPlacement === "center") {
      return viewSize - (viewSize - contentSize) / 2 + snapOutAccelerator;
    }

    return contentSize + snapOutAccelerator;
  }

  /**
   * Calculates the back spacer size based on track type and layout configuration.
   *
   * @param {number} viewSize - The view size along the travel axis.
   * @param {number} contentSize - The content size along the travel axis.
   * @param {number} snapOutAccelerator - The snap-out accelerator value.
   * @param {{ isCenteredTrack: boolean, backSpacerEdgePadding: number, webkitSmallSpacerMode: boolean }} options - Layout options.
   * @returns {number} The back spacer size in pixels.
   */
  #calculateBackSpacerSize(viewSize, contentSize, snapOutAccelerator, options) {
    const { isCenteredTrack, backSpacerEdgePadding, webkitSmallSpacerMode } =
      options;

    if (backSpacerEdgePadding > 0) {
      return viewSize + backSpacerEdgePadding;
    }

    if (isCenteredTrack) {
      if (webkitSmallSpacerMode) {
        return viewSize / 2;
      }
      return (
        viewSize / 2 +
        viewSize -
        (viewSize - contentSize) / 2 +
        snapOutAccelerator
      );
    }

    return viewSize;
  }

  /**
   * Computes the snap-out accelerator value based on browser engine and content size.
   *
   * @param {string | number | ((contentSize: number) => number)} snapOutAcceleration - The acceleration strategy or value.
   * @param {number} viewSize - The view size along the travel axis.
   * @param {number} contentSize - The content size along the travel axis.
   * @param {string} [contentPlacement="end"] - Where the content is placed within the view.
   * @returns {number} The snap-out accelerator value in pixels.
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

      const { browserEngine, detectedPlatform } = capabilities;

      if (browserEngine === "chromium") {
        return effectiveSize <= CHROMIUM_THRESHOLD
          ? 70 + 0.25 * effectiveSize
          : 0.3 * effectiveSize;
      }

      if (browserEngine === "webkit") {
        if (detectedPlatform === "ios" || detectedPlatform === "ipados") {
          return effectiveSize <= WEBKIT_MOBILE_THRESHOLD
            ? 15 + 0.1 * effectiveSize
            : 0.12 * effectiveSize;
        }
        return 0.5 * effectiveSize;
      }

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

    if (typeof snapOutAcceleration === "number") {
      return Math.max(0, Math.min(snapOutAcceleration, contentSize / 2));
    }

    return 0;
  }
}
