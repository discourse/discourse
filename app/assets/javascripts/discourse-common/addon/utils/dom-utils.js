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

function position(element) {
  return {
    top: element.offsetTop,
    left: element.offsetLeft,
  };
}

export default { offset, position };
