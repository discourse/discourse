export function rovingButtonBar(event, containerClass = null) {
  let target = event.target;
  let siblingFinder;

  if (event.code === "ArrowRight") {
    siblingFinder = "nextElementSibling";
  } else if (event.code === "ArrowLeft") {
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
  return (
    element.disabled !== true &&
    (element.tagName === "BUTTON" || element.tagName === "A") &&
    !element.classList.contains("select-kit") &&
    !element.classList.contains("hidden")
  );
}
