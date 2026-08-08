export default class ScrollProgressCalculator {
  controller;

  constructor(controller) {
    this.controller = controller;
  }

  calculateProgress() {
    const { scrollContainer, dimensions, contentPlacement, tracks } =
      this.controller;

    if (!scrollContainer || !dimensions) {
      return null;
    }

    const isHorizontal =
      tracks === "left" || tracks === "right" || tracks === "horizontal";
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
    const isCenteredTrack = tracks === "horizontal" || tracks === "vertical";
    const rawProgress = this.#calculateRawProgress({
      scrollPosition,
      contentSize,
      scrollSize,
      effectiveContentSize,
      edgePadding,
      snapAccelerator,
      isTopOrLeft,
      isCenteredTrack,
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

  #getFirstDetentProgress() {
    const { edgeAlignedNoOvershoot, swipeOutDisabledWithDetent, dimensions } =
      this.controller;

    if (edgeAlignedNoOvershoot && swipeOutDisabledWithDetent) {
      return dimensions?.progressValueAtDetents?.[1]?.exact ?? 0;
    }
    return 0;
  }

  #getMaxClamp() {
    return this.controller.edgeAlignedNoOvershoot ? 1 : 10;
  }

  #getEdgePadding() {
    const { edgeAlignedNoOvershoot, snapToEndDetentsAcceleration } =
      this.controller;

    if (!edgeAlignedNoOvershoot) {
      return 0;
    }

    return snapToEndDetentsAcceleration === "auto" ? 10 : 1;
  }

  #calculateRawProgress({
    scrollPosition,
    contentSize,
    scrollSize,
    effectiveContentSize,
    edgePadding,
    snapAccelerator,
    isTopOrLeft,
    isCenteredTrack,
  }) {
    const { contentPlacement, dimensions, swipeOutDisabledWithDetent } =
      this.controller;

    if (isCenteredTrack) {
      const centerOffset = (scrollSize - contentSize) / 2;
      const restingPosition = dimensions?.webkitSmallSpacerMode
        ? 0
        : snapAccelerator + scrollSize - centerOffset;
      const travelSize = contentSize + centerOffset;

      return Math.max(
        1 - Math.abs(scrollPosition - restingPosition) / travelSize,
        0
      );
    }

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

      if (progress > after && i + 1 < n && progress < detents[i + 1].before) {
        return [i, i + 1];
      }

      if (progress > before && progress < after) {
        return [i, i];
      }
    }

    return null;
  }
}
