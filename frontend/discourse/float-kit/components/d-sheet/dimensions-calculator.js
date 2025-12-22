import { capabilities } from "discourse/services/capabilities";

/**
 * Tolerance value for progress calculations near detent boundaries.
 */
const PROGRESS_TOLERANCE = 2.1;

/**
 * Default edge padding applied when using "auto" snap acceleration.
 */
const AUTO_EDGE_PADDING = 10;

/**
 * Chromium browser threshold for snap accelerator calculation.
 */
const CHROMIUM_THRESHOLD = 1440;

/**
 * WebKit mobile (iOS/iPadOS) threshold for snap accelerator calculation.
 */
const WEBKIT_MOBILE_THRESHOLD = 716;

/**
 * @param {CSSStyleDeclaration} computedStyle
 * @param {string} travelProp
 * @param {string} crossProp
 *
 * @returns {Object}
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
 * @param {number} size
 *
 * @returns {Object}
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
  elements;

  constructor(elements) {
    this.elements = elements;
  }

  /**
   * @param {string} track
   * @param {string} contentPlacement
   * @param {Object} options
   *
   * @returns {Object}
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
   * @param {string} track
   * @param {string} contentPlacement
   * @param {Object} options
   *
   * @returns {Object}
   */
  #buildContext(track, contentPlacement, options) {
    const isHorizontal =
      track === "right" || track === "left" || track === "horizontal";
    const isCenteredTrack = track === "horizontal" || track === "vertical";

    const {
      swipeOutDisabled = false,
      edgeAlignedNoOvershoot = false,
      snapOutAcceleration = "auto",
      snapToEndDetentsAcceleration = "auto",
    } = options;

    const useAutoEdgePadding = snapToEndDetentsAcceleration === "auto";

    return {
      track,
      contentPlacement,
      isHorizontal,
      isCenteredTrack,
      travelProp: isHorizontal ? "width" : "height",
      crossProp: isHorizontal ? "height" : "width",
      swipeOutDisabledWithDetent: !isCenteredTrack && swipeOutDisabled,
      frontSpacerEdgePadding:
        !isCenteredTrack && swipeOutDisabled && useAutoEdgePadding
          ? AUTO_EDGE_PADDING
          : 0,
      backSpacerEdgePadding:
        !isCenteredTrack && edgeAlignedNoOvershoot && useAutoEdgePadding
          ? AUTO_EDGE_PADDING
          : 0,
      snapOutAcceleration,
    };
  }

  /**
   * @param {Object} context
   *
   * @returns {Object}
   */
  #parseInitialDimensions(context) {
    const { view, content } = this.elements;
    const { travelProp, crossProp } = context;

    return {
      view: parseDimensionsFromStyle(
        window.getComputedStyle(view),
        travelProp,
        crossProp
      ),
      content: parseDimensionsFromStyle(
        window.getComputedStyle(content),
        travelProp,
        crossProp
      ),
      detentMarkers: [],
    };
  }

  /**
   * @param {Object} dimensions
   * @param {Object} context
   *
   * @returns {Object}
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
   * @param {HTMLElement[]} markers
   * @param {string} travelProp
   * @param {string} crossProp
   * @param {number} contentSize
   *
   * @returns {Object[]}
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
   * @param {Object[]} detentMarkerDimensions
   * @param {number} contentSize
   *
   * @returns {Object[]}
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
   * @param {Object} dimensions
   * @param {Object} context
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
      }
    );

    dimensions.frontSpacer = {
      travelAxis: createDimensionValue(frontSpacerSize),
    };

    const backSpacerSize = this.#calculateBackSpacerSize(
      viewSize,
      contentSize,
      snapOutAccelerator,
      { isCenteredTrack, backSpacerEdgePadding }
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
   * @param {Object} dimensions
   * @param {HTMLElement} viewElement
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
   * @param {Object} dimensions
   * @param {HTMLElement} viewElement
   * @param {number} snapOutAccelerator
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
   * @param {number} viewSize
   * @param {number} contentSize
   * @param {number} snapOutAccelerator
   * @param {Object[]} detentMarkers
   * @param {Object} options
   *
   * @returns {number}
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
   * @param {number} viewSize
   * @param {number} contentSize
   * @param {number} snapOutAccelerator
   * @param {Object} options
   *
   * @returns {number}
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
   * @param {string|number|Function} snapOutAcceleration
   * @param {number} viewSize
   * @param {number} contentSize
   * @param {string} contentPlacement
   *
   * @returns {number}
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

    return undefined;
  }
}
