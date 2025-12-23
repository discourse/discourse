/**
 * Handles scroll-based progress calculations for the sheet component.
 */
export default class ScrollProgressCalculator {
  /**
   * The sheet controller instance.
   *
   * @type {Object}
   */
  controller;

  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Calculate all progress values from current scroll position.
   *
   * @returns {Object|null} Progress values or null if elements are missing
   */
  calculateProgress() {
    const { scrollContainer, dimensions, contentPlacement, tracks } =
      this.controller;

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
    const { swipeOutDisabled, detentsConfig, dimensions } = this.controller;

    if (swipeOutDisabled && detentsConfig !== undefined) {
      return dimensions?.progressValueAtDetents?.[1]?.exact ?? 0;
    }
    return 0;
  }

  /**
   * Calculate raw progress from scroll position based on content placement and track direction.
   *
   * @param {Object} params - Calculation parameters
   * @param {number} params.scrollPosition - Current scroll position
   * @param {number} params.contentSize - Size of the content on travel axis
   * @param {number} params.effectiveContentSize - Effective size considering placement
   * @param {number} params.edgePadding - Padding at the edges
   * @param {number} params.snapAccelerator - Snap out accelerator value
   * @param {boolean} params.isTopOrLeft - Whether track is top or left
   * @returns {number} Raw progress value
   */
  #calculateRawProgress({
    scrollPosition,
    contentSize,
    effectiveContentSize,
    edgePadding,
    snapAccelerator,
    isTopOrLeft,
  }) {
    const { contentPlacement } = this.controller;

    const divisor =
      contentPlacement === "center" ? effectiveContentSize : contentSize;

    if (isTopOrLeft) {
      const numerator =
        contentPlacement === "center"
          ? effectiveContentSize + edgePadding - scrollPosition
          : contentSize + edgePadding - scrollPosition;
      return numerator / divisor;
    }

    return (scrollPosition - snapAccelerator) / divisor;
  }

  /**
   * Calculate segment progress for detent determination.
   *
   * @param {Object} params - Calculation parameters
   * @param {number} params.scrollPosition - Current scroll position
   * @param {number} params.rawProgress - Previously calculated raw progress
   * @param {number} params.edgePadding - Padding at the edges
   * @param {number} params.contentSize - Size of the content on travel axis
   * @returns {number} Segment progress value
   */
  #calculateSegmentProgress({
    scrollPosition,
    rawProgress,
    edgePadding,
    contentSize,
  }) {
    const { dimensions } = this.controller;

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
   * Exact boundary checks are preserved to match original implementation.
   *
   * @param {number} segmentProgress - Segment progress value
   * @returns {Array<number>|null} Segment as [start, end] indices or null if no change
   */
  determineSegment(segmentProgress) {
    const { dimensions } = this.controller;
    const detents = dimensions?.progressValueAtDetents;

    if (!detents) {
      return null;
    }

    if (segmentProgress <= 0) {
      return [0, 0];
    }

    const n = detents.length;
    for (let i = 0; i < n; i++) {
      const { before, after } = detents[i];

      // Moving between detents
      if (
        segmentProgress > after &&
        i + 1 < n &&
        segmentProgress < detents[i + 1].before
      ) {
        return [i, i + 1];
      }

      // Snapped to detent
      if (segmentProgress > before && segmentProgress < after) {
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
