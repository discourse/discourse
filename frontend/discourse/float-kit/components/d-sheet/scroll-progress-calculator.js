/**
 * Handles scroll-based progress calculations.
 *
 * @class ScrollProgressCalculator
 */
export default class ScrollProgressCalculator {
  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.c = controller;
  }

  /**
   * Calculate all progress values from current scroll position.
   *
   * @returns {{ rawProgress: number, clampedProgress: number, stackingProgress: number, segmentProgress: number } | null}
   */
  calculateProgress() {
    const { scrollContainer, dimensions, contentPlacement, tracks } = this.c;

    if (!scrollContainer || !dimensions) {
      return null;
    }

    const isHorizontal = tracks === "left" || tracks === "right";
    const scrollPosition = isHorizontal
      ? scrollContainer.scrollLeft
      : scrollContainer.scrollTop;
    const contentSize = dimensions.content?.travelAxis?.unitless ?? 1;
    const scrollSize = dimensions.scroll?.travelAxis?.unitless ?? contentSize;
    const effectiveContentSize =
      contentPlacement !== "center"
        ? contentSize
        : contentSize + (scrollSize - contentSize) / 2;

    const edgePadding = dimensions.frontSpacerEdgePadding ?? 0;
    const snapAccelerator =
      dimensions.snapOutAccelerator?.travelAxis?.unitless ?? 0;

    const firstDetentProgress = this.#getFirstDetentProgress();

    const isTopOrLeft = tracks === "top" || tracks === "left";
    const rawProgress = this.#calculateRawProgress({
      scrollPosition,
      contentSize,
      effectiveContentSize,
      edgePadding,
      snapAccelerator,
      isTopOrLeft,
    });

    const clampedProgress = Math.max(
      firstDetentProgress,
      Math.min(1, rawProgress)
    );
    const stackingProgress = Math.max(0, Math.min(1, rawProgress));

    const segmentProgress = this.#calculateSegmentProgress({
      scrollPosition,
      rawProgress,
      edgePadding,
      contentSize,
    });

    return {
      rawProgress,
      clampedProgress,
      stackingProgress,
      segmentProgress,
    };
  }

  /**
   * Get the first detent progress value for clamping.
   *
   * @returns {number}
   */
  #getFirstDetentProgress() {
    const { swipeOutDisabled, detentsConfig, dimensions } = this.c;

    if (swipeOutDisabled && detentsConfig !== undefined) {
      return dimensions?.progressValueAtDetents?.[1]?.exact ?? 0;
    }
    return 0;
  }

  /**
   * Calculate raw progress from scroll position.
   *
   * @param {Object} params - Calculation parameters
   * @returns {number}
   */
  #calculateRawProgress({
    scrollPosition,
    contentSize,
    effectiveContentSize,
    edgePadding,
    snapAccelerator,
    isTopOrLeft,
  }) {
    const { contentPlacement } = this.c;
    let result;

    if (contentPlacement === "center") {
      if (isTopOrLeft) {
        result =
          (effectiveContentSize + edgePadding - scrollPosition) /
          effectiveContentSize;
      } else {
        result = (scrollPosition - snapAccelerator) / effectiveContentSize;
      }
    } else {
      if (isTopOrLeft) {
        result = (contentSize + edgePadding - scrollPosition) / contentSize;
      } else {
        result = (scrollPosition - snapAccelerator) / contentSize;
      }
    }

    return result;
  }

  /**
   * Calculate segment progress for detent determination.
   *
   * @param {Object} params - Calculation parameters
   * @returns {number}
   */
  #calculateSegmentProgress({
    scrollPosition,
    rawProgress,
    edgePadding,
    contentSize,
  }) {
    const { dimensions } = this.c;

    if (dimensions?.swipeOutDisabledWithDetent) {
      const firstMarkerSize =
        dimensions.detentMarkers[0]?.travelAxis?.unitless ?? 0;
      const scrollOffset = firstMarkerSize - edgePadding;
      return (scrollPosition + scrollOffset) / contentSize;
    }
    return rawProgress;
  }

  /**
   * Determine the current segment from progress and detents.
   *
   * @param {number} segmentProgress - Segment progress value
   * @returns {[number, number] | null} Segment as [start, end] or null if no change
   */
  determineSegment(segmentProgress) {
    const { dimensions } = this.c;

    if (!dimensions?.progressValueAtDetents) {
      return null;
    }

    const detents = dimensions.progressValueAtDetents;
    const n = detents.length;

    if (segmentProgress <= 0) {
      return [0, 0];
    }

    for (let i = 0; i < n; i++) {
      const detent = detents[i];
      const after = detent.after;
      if (
        segmentProgress > after &&
        i + 1 < n &&
        segmentProgress < detents[i + 1].before
      ) {
        return [i, i + 1];
      } else if (segmentProgress > detent.before && segmentProgress < after) {
        return [i, i];
      }
    }

    // Fallback: if segmentProgress >= 1, set to last detent
    if (segmentProgress >= 1) {
      const lastDetent = n - 1;
      return [lastDetent, lastDetent];
    }

    return null;
  }
}
