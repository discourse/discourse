function isWindow(obj) {
  return obj != null && obj === window;
}

function scrollTop(element) {
  return element
    ? element.scrollTop
    : window.pageYOffset || document.documentElement.scrollTop;
}

function offset(element) {
  // note that getBoundingClientRect forces a reflow.
  // When used in critical performance conditions
  // you might want to move to more involved solution
  // such as implementing an IntersectionObserver and
  // using its boundingClientRect property
  const rect = element.getBoundingClientRect();
  return {
    top: rect.top + window.scrollY,
    left: rect.left + window.scrollX,
  };
}

function height(element) {
  if (isWindow(element)) {
    return element.innerHeight;
  }

  return element.clientHeight;
}

function width(element) {
  if (isWindow(element)) {
    return element.innerWidth;
  }

  return element.clientWidth;
}

function position(element) {
  return {
    top: element.offsetTop,
    left: element.offsetLeft,
  };
}

function scrollToTop(element = window, top = 0) {
  element.scroll({ top, left: 0 });
}

export default { scrollToTop, scrollTop, offset, height, width, position };
