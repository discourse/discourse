import tippy from "tippy.js";

function stopPropagation(instance, event) {
  event.preventDefault();
  event.stopPropagation();
}
function hasTouchCapabilities() {
  return navigator.maxTouchPoints > 1 || "ontouchstart" in window;
}

export default function createDTooltip(target, content) {
  return tippy(target, {
    interactive: false,
    content,
    trigger: hasTouchCapabilities() ? "click" : "mouseenter",
    theme: "d-tooltip",
    arrow: false,
    placement: "bottom-start",
    onTrigger: stopPropagation,
    onUntrigger: stopPropagation,
  });
}
