import { capabilities } from "discourse/services/capabilities";

const PROGRESS_TOLERANCE = 2.1;
const AUTO_EDGE_PADDING = 10;
const CHROMIUM_THRESHOLD = 1440;
const WEBKIT_MOBILE_THRESHOLD = 716;

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
function createDimensionValue(size) {
  return {
    px: `${size}px`,
    unitless: size,
    unitlessRoundedDown: Math.floor(size),
  };
}

export default class DimensionCalculator {
  elements;

  constructor(elements) {
    this.elements = elements;
  }

  calculateDimensions(track, contentPlacement, options = {}) {
    const context = this.#buildContext(track, contentPlacement, options);
    const dimensions = this.#parseInitialDimensions(context);
    const detents = this.#calculateDetents(dimensions, context);
    Object.assign(dimensions, detents);

    this.#calculateDerivedDimensions(dimensions, context);
    this.#applyVariables(dimensions);

    return dimensions;
  }

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

  #parseInitialDimensions(context) {
    const { view, content } = this.elements;
    const { travelProp, crossProp } = context;
    const viewDimensions = parseDimensionsFromStyle(
      window.getComputedStyle(view),
      travelProp,
      crossProp
    );

    return {
      webkitSmallSpacerMode: context.webkitSmallSpacerMode,
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

  #calculateDerivedDimensions(dimensions, context) {
    const {
      contentPlacement,
      isCenteredTrack,
      swipeOutDisabledWithDetent,
      frontSpacerEdgePadding,
      backSpacerEdgePadding,
      snapOutAcceleration,
      webkitSmallSpacerMode,
    } = context;

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

    dimensions.snapOutAccelerator = {
      travelAxis: createDimensionValue(snapOutAccelerator),
    };
  }

  #applyVariables(dimensions) {
    const { view: viewElement } = this.elements;

    this.#applyViewContentStyles(dimensions, viewElement);

    viewElement.style.setProperty(
      "--d-sheet-front-spacer",
      dimensions.frontSpacer.travelAxis.px
    );

    viewElement.style.setProperty(
      "--d-sheet-back-spacer",
      dimensions.backSpacer.travelAxis.px
    );

    this.#applyDetentAcceleratorStyles(dimensions, viewElement);
  }

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

  #applyDetentAcceleratorStyles(dimensions, viewElement) {
    if (dimensions.detentMarkers?.length > 0) {
      viewElement.style.setProperty(
        "--d-sheet-first-detent-size",
        dimensions.detentMarkers[0].travelAxis.px
      );
    }

    viewElement.style.setProperty(
      "--d-sheet-snap-accelerator",
      dimensions.snapOutAccelerator.travelAxis.px
    );
  }

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
