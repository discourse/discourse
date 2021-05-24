export default function (element) {
  if (!element) {
    return;
  }

  const $window = $(window),
    rect = element.getBoundingClientRect();

  return (
    rect.top >= 0 &&
    rect.left >= 0 &&
    rect.bottom <= $window.height() &&
    rect.right <= $window.width()
  );
}
