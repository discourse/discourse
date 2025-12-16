import { capabilities } from "discourse/services/capabilities";

/**
 * Tolerance value for progress calculations near detent boundaries.
 * Used to determine "before" and "after" progress thresholds.
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
 * Below this value, a linear formula is used; above, a percentage.
 * @type {number}
 */
const CHROMIUM_THRESHOLD = 1440;

/**
 * WebKit mobile (iOS/iPadOS) threshold for snap accelerator calculation.
 * @type {number}
 */
const WEBKIT_MOBILE_THRESHOLD = 716;

/**
 * Parse dimensions from a computed style for both travel and cross axes.
 *
 * @param {CSSStyleDeclaration} computedStyle - The computed style object
 * @param {string} travelProp - CSS property for travel axis ("width" or "height")
 * @param {string} crossProp - CSS property for cross axis ("height" or "width")
 * @returns {Object} Dimension object with travelAxis and crossAxis
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
 * Create a dimension value object from a numeric size.
 *
 * @param {number} size - The size in pixels
 * @returns {Object} Dimension value with px, unitless, and unitlessRoundedDown
 */
function createDimensionValue(size) {
  return {
    px: `${size}px`,
    unitless: size,
    unitlessRoundedDown: Math.floor(size),
  };
}

/**
 * Calculates and applies CSS dimensions for sheet positioning and scroll behavior.
 * Handles view/content sizing, detent markers, spacers, and snap accelerators.
 *
 * The calculator performs a two-pass approach:
 * 1. First pass: Apply view/content dimensions so CSS variables can resolve
 * 2. Second pass: Read detent markers and calculate final spacer values
 */
export default class DimensionCalculator {
  /** @type {Object} */
  elements;

  /**
   * Creates a new DimensionCalculator instance.
   *
   * @param {Object} elements - DOM element references
   * @param {HTMLElement} elements.view - The view element (scroll container parent)
   * @param {HTMLElement} elements.content - The content element
   * @param {HTMLElement[]} elements.detentMarkers - Array of detent marker elements
   */
  constructor(elements) {
    this.elements = elements;
  }

  /**
   * Calculate all dimensions needed for sheet positioning.
   *
   * @param {string} track - Track direction: "bottom", "top", "left", "right", "horizontal", "vertical"
   * @param {string} contentPlacement - Content placement: "start", "center", "end"
   * @param {Object} [options={}] - Additional options
   * @param {boolean} [options.swipeOutDisabled=false] - Disables swipe-to-dismiss
   * @param {boolean} [options.edgeAlignedNoOvershoot=false] - Prevents overshoot at edges
   * @param {string|number|Function} [options.snapOutAcceleration="auto"] - Snap out acceleration mode
   * @param {string} [options.snapToEndDetentsAcceleration="auto"] - Snap to end detents acceleration
   * @returns {Object} Calculated dimensions including view, content, detentMarkers, and progress values
   */
  calculateDimensions(track, contentPlacement, options = {}) {
    const {
      swipeOutDisabled = false,
      edgeAlignedNoOvershoot = false,
      snapOutAcceleration = "auto",
      snapToEndDetentsAcceleration = "auto",
    } = options;

    const {
      view: viewElement,
      content: contentElement,
      detentMarkers,
    } = this.elements;

    const isHorizontal = this.#isHorizontalTrack(track);
    const travelProp = isHorizontal ? "width" : "height";
    const crossProp = isHorizontal ? "height" : "width";

    const viewDimensions = parseDimensionsFromStyle(
      window.getComputedStyle(viewElement),
      travelProp,
      crossProp
    );

    const contentDimensions = parseDimensionsFromStyle(
      window.getComputedStyle(contentElement),
      travelProp,
      crossProp
    );

    const isCenteredTrack = track === "horizontal" || track === "vertical";
    const swipeOutDisabledWithDetent = !isCenteredTrack && swipeOutDisabled;
    const backSpacerEdgeAligned = !isCenteredTrack && edgeAlignedNoOvershoot;

    const useAutoEdgePadding = snapToEndDetentsAcceleration === "auto";
    const frontSpacerEdgePadding =
      swipeOutDisabledWithDetent && useAutoEdgePadding ? AUTO_EDGE_PADDING : 0;
    const backSpacerEdgePadding =
      backSpacerEdgeAligned && useAutoEdgePadding ? AUTO_EDGE_PADDING : 0;

    const calculationContext = {
      track,
      isCenteredTrack,
      swipeOutDisabledWithDetent,
      frontSpacerEdgePadding,
      backSpacerEdgePadding,
      snapOutAcceleration,
    };

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
      calculationContext
    );

    // Pass 2: Read detent markers and calculate final dimensions
    const detentMarkerDimensions = this.#calculateDetentMarkerDimensions(
      detentMarkers,
      travelProp,
      crossProp,
      contentDimensions.travelAxis.unitless
    );

    const progressAtDetents = this.#calculateProgressAtDetents(
      detentMarkerDimensions,
      contentDimensions.travelAxis.unitless
    );

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
      calculationContext
    );

    return finalDimensions;
  }

  /**
   * Check if the track direction is horizontal.
   *
   * @param {string} track - Track direction
   * @returns {boolean} True if horizontal track
   */
  #isHorizontalTrack(track) {
    return track === "right" || track === "left" || track === "horizontal";
  }

  /**
   * Calculate dimensions for all detent markers.
   *
   * @param {HTMLElement[]} markers - Detent marker elements
   * @param {string} travelProp - CSS property for travel axis
   * @param {string} crossProp - CSS property for cross axis
   * @param {number} contentSize - Total content size in pixels
   * @returns {Object[]} Array of detent marker dimensions with accumulated offsets
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

    // Adjust the last marker to represent remaining content size
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
   * Calculate progress values at each detent position.
   * Progress ranges from 0 (closed) to 1 (fully open).
   *
   * @param {Object[]} detentMarkerDimensions - Detent marker dimensions
   * @param {number} contentSize - Total content size in pixels
   * @returns {Object[]} Array of progress entries with before, exact, and after values
   */
  #calculateProgressAtDetents(detentMarkerDimensions, contentSize) {
    const createProgressEntry = (baseOffset) => ({
      before: (baseOffset - PROGRESS_TOLERANCE) / contentSize,
      exact: baseOffset / contentSize,
      after: (baseOffset + PROGRESS_TOLERANCE) / contentSize,
    });

    // Start with closed state (progress = 0)
    const progressAtDetents = [createProgressEntry(0)];

    // Add progress entry for each marker except the last one
    // (last marker represents full height)
    detentMarkerDimensions.slice(0, -1).forEach((marker) => {
      const offset = marker.accumulatedOffsets.travelAxis.unitless;
      progressAtDetents.push(createProgressEntry(offset));
    });

    // Final entry for full height (progress = 1.0)
    progressAtDetents.push(createProgressEntry(contentSize));

    return progressAtDetents;
  }

  /**
   * Apply CSS custom properties on the view element.
   *
   * @param {Object} dimensions - The calculated dimensions
   * @param {HTMLElement} viewElement - The view element
   * @param {string} [contentPlacement="end"] - Content placement
   * @param {Object} context - Calculation context
   * @param {boolean} context.isCenteredTrack - Whether using horizontal/vertical track
   * @param {boolean} context.swipeOutDisabledWithDetent - Whether swipe out is disabled with detent
   * @param {number} context.frontSpacerEdgePadding - Front spacer edge padding
   * @param {number} context.backSpacerEdgePadding - Back spacer edge padding
   * @param {string|number|Function} context.snapOutAcceleration - Snap out acceleration setting
   */
  #applyDimensionVariables(
    dimensions,
    viewElement,
    contentPlacement = "end",
    context = {}
  ) {
    const {
      isCenteredTrack = false,
      swipeOutDisabledWithDetent = false,
      frontSpacerEdgePadding = 0,
      backSpacerEdgePadding = 0,
      snapOutAcceleration = "auto",
    } = context;

    this.#applyViewContentVariables(dimensions, viewElement);

    const viewSize = dimensions.view?.travelAxis?.unitless || 0;
    const contentSize = dimensions.content?.travelAxis?.unitless || 0;

    const snapOutAccelerator = this.#calculateSnapOutAccelerator(
      snapOutAcceleration,
      viewSize,
      contentSize,
      contentPlacement
    );

    if (dimensions.view && dimensions.content) {
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
        }
      );

      dimensions.frontSpacer = {
        travelAxis: createDimensionValue(frontSpacerSize),
      };

      viewElement.style.setProperty(
        "--d-sheet-front-spacer",
        `${frontSpacerSize}px`
      );

      const backSpacerSize = this.#calculateBackSpacerSize(
        viewSize,
        contentSize,
        snapOutAccelerator,
        { isCenteredTrack, backSpacerEdgePadding }
      );

      viewElement.style.setProperty(
        "--d-sheet-back-spacer",
        `${backSpacerSize}px`
      );
    }

    this.#applyDetentAndAcceleratorVariables(
      dimensions,
      viewElement,
      snapOutAccelerator
    );
  }

  /**
   * Apply view and content dimension CSS variables.
   *
   * @param {Object} dimensions - The dimensions object
   * @param {HTMLElement} viewElement - The view element
   */
  #applyViewContentVariables(dimensions, viewElement) {
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
  }

  /**
   * Apply detent and accelerator CSS variables.
   *
   * @param {Object} dimensions - The dimensions object
   * @param {HTMLElement} viewElement - The view element
   * @param {number} snapOutAccelerator - Calculated snap accelerator value
   */
  #applyDetentAndAcceleratorVariables(
    dimensions,
    viewElement,
    snapOutAccelerator
  ) {
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
   * Calculate the front spacer size based on track type and placement.
   *
   * @param {number} viewSize - View size in pixels
   * @param {number} contentSize - Content size in pixels
   * @param {number} snapOutAccelerator - Snap accelerator value
   * @param {Object[]} detentMarkers - Detent marker dimensions
   * @param {Object} options - Calculation options
   * @returns {number} Front spacer size in pixels
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
    } = options;

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
   * Calculate the back spacer size based on track type and edge padding.
   *
   * @param {number} viewSize - View size in pixels
   * @param {number} contentSize - Content size in pixels
   * @param {number} snapOutAccelerator - Snap accelerator value
   * @param {Object} options - Calculation options
   * @returns {number} Back spacer size in pixels
   */
  #calculateBackSpacerSize(viewSize, contentSize, snapOutAccelerator, options) {
    const { isCenteredTrack, backSpacerEdgePadding } = options;

    if (isCenteredTrack) {
      return (
        viewSize / 2 +
        viewSize -
        (viewSize - contentSize) / 2 +
        snapOutAccelerator
      );
    }

    if (backSpacerEdgePadding > 0) {
      return viewSize + backSpacerEdgePadding;
    }

    return viewSize;
  }

  /**
   * Calculate snap out accelerator value for scroll-snap behavior.
   * Browser-specific calculations ensure smooth scroll snapping across platforms.
   *
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

      // Gecko (Firefox) or unknown browser
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
