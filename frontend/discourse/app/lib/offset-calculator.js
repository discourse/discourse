export function scrollTopFor(y) {
  return y - offsetCalculator();
}

export function headerOffset() {
  return (
    parseInt(
      document.documentElement.style.getPropertyValue("--header-offset"),
      10
    ) || 0
  );
}

export default function offsetCalculator() {
  const min = headerOffset();

  // on mobile, just use the header
  if (document.documentElement.classList.contains("mobile-view")) {
    return min;
  }

  const windowHeight = window.innerHeight;
  const documentHeight = document.body.clientHeight;
  const topicBottomOffsetTop =
    document.getElementById("topic-bottom").offsetTop;

  // the footer is bigger than the window, we can scroll down past the last post
  if (documentHeight - windowHeight > topicBottomOffsetTop) {
    return min;
  }

  const scrollTop = window.scrollY;
  const visibleBottomHeight = scrollTop + windowHeight - topicBottomOffsetTop;

  if (visibleBottomHeight > 0) {
    const bottomHeight = documentHeight - topicBottomOffsetTop;
    const offset =
      ((windowHeight - bottomHeight) * visibleBottomHeight) / bottomHeight;
    return Math.max(min, offset);
  }

  return min;
}
