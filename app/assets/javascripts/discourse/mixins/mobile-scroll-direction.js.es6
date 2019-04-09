// Small buffer so that very tiny scrolls don't trigger mobile header switch
const MOBILE_SCROLL_TOLERANCE = 5;

export default Ember.Mixin.create({
  _mobileLastScroll: null,

  calculateDirection(offset) {
    // Difference between this scroll and the one before it.
    const delta = Math.floor(offset - this._mobileLastScroll);

    // This is a tiny scroll, so we ignore it.
    if (delta <= MOBILE_SCROLL_TOLERANCE && delta >= -MOBILE_SCROLL_TOLERANCE)
      return;

    const prevDirection = this.mobileScrollDirection;
    const currDirection = delta > 0 ? "down" : null;

    // Handle Safari overscroll first
    if (offset < 0) {
      this.set("mobileScrollDirection", null);
    } else if (currDirection !== prevDirection) {
      this.set("mobileScrollDirection", currDirection);
    }

    // We store this to compare against it the next time the user scrolls
    this._mobileLastScroll = Math.floor(offset);

    // If the user reaches the very bottom of the topic, we want to reset the
    // scroll direction in order for the header to switch back.
    const distanceToBottom = Math.floor(
      $("body").height() - offset - $(window).height()
    );

    // Not at the bottom yet
    if (distanceToBottom > 0) return;

    // We're at the bottom now, so we reset the direction.
    this.set("mobileScrollDirection", null);
  }
});
