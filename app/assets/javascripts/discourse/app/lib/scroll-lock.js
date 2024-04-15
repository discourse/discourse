/**
   lock scroll of an element using overflow:hidden
   preserve gutter with scroll detection
*/
function lockScroll(element = document.scrollingElement) {
  let scrollGap = 0;

  //Add scroll gap if using default scrolling element
  if (element === document.scrollingElement) {
    scrollGap = Math.max(0, window.innerWidth - element.clientWidth);
  } else {
    scrollGap = element.offsetWidth - element.clientWidth;
  }
  element.style.setProperty("--scroll-gap", `${scrollGap}px`);
  element.classList.add("scroll-lock");
}

function unlockScroll(element = document.scrollingElement) {
  element.classList.remove("scroll-lock");
  element.style.setProperty("--scroll-gap", null);
}

export default function scrollLock(lock, element = document.scrollingElement) {
  if (lock) {
    lockScroll(element);
  } else {
    unlockScroll(element);
  }
}
