export function rovingButtonBar(event, containerClass = null) {
  let target = event.target;
  let siblingFinder;

  if (event.code === "ArrowRight" || event.keyCode === 39) {
    siblingFinder = "nextElementSibling";
  } else if (event.code === "ArrowLeft" || event.keyCode === 37) {
    siblingFinder = "previousElementSibling";
  } else {
    return false;
  }

  if (containerClass) {
    while (
      target.parentNode &&
      !target.parentNode.classList.contains(containerClass)
    ) {
      target = target.parentNode;
    }
  }

  let focusable = target[siblingFinder];
  while (focusable && !isActionable(focusable)) {
    focusable = focusable[siblingFinder];

    if (focusable?.tagName === "DETAILS") {
      focusable = focusable.querySelector("summary");
    }
  }

  if (!focusable) {
    return false;
  }

  focusable.focus();

  return true;
}

function isActionable(element) {
  if (!element) {
    return false;
  }

  return (
    element.disabled !== true &&
    (element.tagName === "BUTTON" ||
      element.tagName === "A" ||
      element.getAttribute("role") === "switch" ||
      element.getAttribute("role") === "button") &&
    !element.classList.contains("select-kit") &&
    !element.classList.contains("hidden")
  );
}
