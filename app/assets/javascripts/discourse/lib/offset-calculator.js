export function scrollTopFor(y) {
  return y - offsetCalculator();
}

export function minimumOffset() {
  const $header = $("header.d-header");
  const headerHeight = $header.outerHeight(true) || 0;
  const headerPositionTop = $header.position().top;
  return headerHeight + headerPositionTop;
}

export default function offsetCalculator() {
  const min = minimumOffset();

  // on mobile, just use the header
  if ($("html").hasClass("mobile-view")) return min;

  const $window = $(window);
  const windowHeight = $window.height();
  const documentHeight = $(document).height();
  const topicBottomOffsetTop = $("#topic-bottom").offset().top;

  // the footer is bigger than the window, we can scroll down past the last post
  if (documentHeight - windowHeight > topicBottomOffsetTop) return min;

  const scrollTop = $window.scrollTop();
  const visibleBottomHeight = scrollTop + windowHeight - topicBottomOffsetTop;

  if (visibleBottomHeight > 0) {
    const bottomHeight = documentHeight - topicBottomOffsetTop;
    const offset =
      ((windowHeight - bottomHeight) * visibleBottomHeight) / bottomHeight;
    return Math.max(min, offset);
  }

  return min;
}
