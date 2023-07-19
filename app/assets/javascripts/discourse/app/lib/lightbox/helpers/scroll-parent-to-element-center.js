export async function scrollParentToElementCenter({ element, isRTL }) {
  const {
    offsetWidth: width,
    offsetHeight: height,
    parentElement: parent,
  } = element;

  // if isRTL, make it relative to the right side of the viewport
  const modifier = isRTL ? -1 : 1;

  const x = ((width - parent.offsetWidth) / 2) * modifier;
  const y = (height - parent.offsetHeight) / 2;

  parent.scrollLeft = parseInt(x, 10);
  parent.scrollTop = parseInt(y, 10);
}
