/**
   lock scroll of an element using overflow:hidden
   preserve gutter with scroll detection
*/
export default class ScrollLock {
  static scrollingElement = document.scrollingElement;
  static lock(element) {
    let scrollGap = 0;

    //Add scroll gap if using default scrolling element
    if (!element) {
      element = this.scrollingElement;
      scrollGap = Math.max(
        0,
        window.innerWidth - this.scrollingElement.clientWidth
      );
      this.scrollingElement.style.setProperty("--scroll-gap", `${scrollGap}px`);
    }
    element.classList.add("scroll-lock");
  }
  static unlock(element) {
    element = element || this.scrollingElement;
    element.classList.remove("scroll-lock");
    element.style.setProperty("--scroll-gap", null);
  }
  static toggle(bool) {
    if (bool) {
      this.lock();
    } else {
      this.unlock();
    }
  }
}
