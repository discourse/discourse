export function isCloneElement(element) {
  return element?.getAttribute("data-d-scroll-clone") === "true";
}
