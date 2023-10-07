/**
   lock scroll of an element using overflow:hidden
   preserve gutter with scroll detection
*/
export default class ScrollLock {
  static scrollingElement = document.scrollingElement;
  static lock() {
    const scrollGap = Math.max(
      0,
      window.innerWidth - this.scrollingElement.clientWidth
    );
    this.scrollingElement.style.setProperty("--scroll-gap", `${scrollGap}px`);
    this.scrollingElement.classList.add("scroll-lock");
  }
  static unlock() {
    this.scrollingElement.classList.remove("scroll-lock");
    this.scrollingElement.style.setProperty("--scroll-gap", null);
  }
  static toggle(bool) {
    if (bool) {
      this.lock();
    } else {
      this.unlock();
    }
  }
}
