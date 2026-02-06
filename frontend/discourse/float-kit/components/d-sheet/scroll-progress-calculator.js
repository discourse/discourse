/**
 * @typedef {Object} ProgressResult
 * @property {number} rawProgress - Unbounded progress from scroll position
 * @property {number} clampedProgress - Progress clamped between first detent and max
 */

/**
 * Handles scroll-based progress calculations for the sheet component.
 */
export default class ScrollProgressCalculator {
  /**
   * The sheet controller instance.
   *
   * @type {import("./controller").default}
   */
  controller;

  /**
   * @param {import("./controller").default} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Calculate all progress values from current scroll position.
   *
   * @returns {ProgressResult|null} Progress values or null if elements are missing
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

    const edgePadding = this.#getEdgePadding();
    const snapAccelerator =
      dimensions.snapOutAccelerator?.travelAxis?.unitless ?? 0;

    const firstDetentProgress = this.#getFirstDetentProgress();
    const maxClamp = this.#getMaxClamp();

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
      Math.min(maxClamp, rawProgress)
    );
    return {
      rawProgress,
      clampedProgress,
    };
  }

  /**
   * Get the first detent progress value for clamping.
   *
   * @returns {number}
   */
  #getFirstDetentProgress() {
    const { edgeAlignedNoOvershoot, swipeOutDisabledWithDetent, dimensions } =
      this.controller;

    if (edgeAlignedNoOvershoot && swipeOutDisabledWithDetent) {
      return dimensions?.progressValueAtDetents?.[1]?.exact ?? 0;
    }
    return 0;
  }

  /**
   * Get the max clamp value for progress.
   *
   * @returns {number}
   */
  #getMaxClamp() {
    return this.controller.edgeAlignedNoOvershoot ? 1 : 10;
  }

  /**
   * Get the edge padding value for progress calculations.
   *
   * @returns {number}
   */
  #getEdgePadding() {
    const { edgeAlignedNoOvershoot, snapToEndDetentsAcceleration } =
      this.controller;

    if (!edgeAlignedNoOvershoot) {
      return 0;
    }

    return snapToEndDetentsAcceleration === "auto" ? 10 : 1;
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
    const { contentPlacement, dimensions, swipeOutDisabledWithDetent } =
      this.controller;

    if (dimensions?.webkitSmallSpacerMode) {
      return isTopOrLeft
        ? 1 - scrollPosition / contentSize
        : 1 + scrollPosition / contentSize;
    }

    const divisor =
      contentPlacement === "center" ? effectiveContentSize : contentSize;

    if (isTopOrLeft) {
      const numerator =
        contentPlacement === "center"
          ? effectiveContentSize + edgePadding - scrollPosition
          : contentSize + edgePadding - scrollPosition;
      return numerator / divisor;
    }

    if (contentPlacement !== "center" && swipeOutDisabledWithDetent) {
      const firstDetentSize =
        dimensions?.detentMarkers?.[0]?.travelAxis?.unitless;
      const offset = (firstDetentSize ?? 0) - edgePadding;
      return (scrollPosition + offset) / divisor;
    }

    return (scrollPosition - snapAccelerator) / divisor;
  }

  /**
   * Determine the current segment from progress and detents.
   *
   * @param {number} progress - Segment progress value
   * @returns {[number, number]|null} Segment as [start, end] indices or null if no change
   */
  determineSegment(progress) {
    const { dimensions } = this.controller;
    const detents = dimensions?.progressValueAtDetents;

    if (!detents) {
      return null;
    }

    if (progress <= 0) {
      return [0, 0];
    }

    const n = detents.length;
    for (let i = 0; i < n; i++) {
      const { before, after } = detents[i];

      // Moving between detents
      if (progress > after && i + 1 < n && progress < detents[i + 1].before) {
        return [i, i + 1];
      }

      // Snapped to detent
      if (progress > before && progress < after) {
        return [i, i];
      }
    }

    // Fallback: if progress >= 1, set to last detent
    if (progress >= 1) {
      const lastDetent = n - 1;
      return [lastDetent, lastDetent];
    }

    return null;
  }
}
