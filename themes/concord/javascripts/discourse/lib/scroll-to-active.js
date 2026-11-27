/**
 * Scrolls the channel list so the current channel's row is on screen,
 * centred if it wasn't, and clear of the slide-in list's sticky server name.
 * Done by hand rather than with `scrollIntoView`, which would also scroll the
 * page sideways while the slide-in list is still off screen.
 *
 * @param {Element} list The channel list, or anything inside it.
 */
export default function scrollToActive(list) {
  const row = list?.querySelector(".sidebar-section-link.active");
  let scroller = row?.parentElement;

  while (scroller && !["auto", "scroll"].includes(scrollerStyle(scroller))) {
    scroller = scroller.parentElement;
  }

  if (!scroller || scroller === document.scrollingElement) {
    return;
  }

  const rowRect = row.getBoundingClientRect();
  const top =
    rowRect.top - scroller.getBoundingClientRect().top + scroller.scrollTop;
  const bottom = top + rowRect.height;

  const header = scroller.querySelector(".concord-server-header");
  const covered =
    header && getComputedStyle(header).position === "sticky"
      ? header.offsetHeight
      : 0;

  if (
    top < scroller.scrollTop + covered ||
    bottom > scroller.scrollTop + scroller.clientHeight
  ) {
    scroller.scrollTop =
      top - covered - (scroller.clientHeight - covered - rowRect.height) / 2;
  }
}

function scrollerStyle(element) {
  return getComputedStyle(element).overflowY;
}
