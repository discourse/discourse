const BOTTOM_VISIBILITY_SLACK = 10;

export function checkMessageBottomVisibility(
  list: Element,
  message: Element
): boolean {
  const distanceToTop = window.pageYOffset + list.getBoundingClientRect().top;
  const bounding = message.getBoundingClientRect();
  return (
    bounding.bottom - distanceToTop <=
    list.clientHeight + BOTTOM_VISIBILITY_SLACK
  );
}

export function checkMessageTopVisibility(
  list: Element,
  message: Element
): boolean {
  const distanceToTop = window.pageYOffset + list.getBoundingClientRect().top;
  const bounding = message.getBoundingClientRect();
  return bounding.top - distanceToTop >= -1;
}
