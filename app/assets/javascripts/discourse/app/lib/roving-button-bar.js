export function rovingButtonBar(event, containerClass = null) {
  let target = event.target;
  let siblingFinder;

  if (event.code === "ArrowRight") {
    siblingFinder = "nextElementSibling";
  } else if (event.code === "ArrowLeft") {
    siblingFinder = "previousElementSibling";
  } else {
    return true;
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
  if (focusable) {
    while (
      focusable.tagName !== "BUTTON" &&
      focusable.tagName !== "A" &&
      !focusable.classList.contains("select-kit") &&
      !focusable.classList.contains("hidden")
    ) {
      focusable = focusable[siblingFinder];
    }

    if (focusable?.tagName === "DETAILS") {
      focusable = focusable.querySelector("summary");
    }

    focusable?.focus();
  }

  return true;
}
