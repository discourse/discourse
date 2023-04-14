import { showPopover } from "discourse/lib/d-popover";

export default {
  name: "d-popover",

  initialize() {
    ["click", "mouseover"].forEach((eventType) => {
      document.addEventListener(eventType, (e) => {
        if (e.target.dataset.tooltip || e.target.dataset.popover) {
          showPopover(e, {
            interactive: false,
            content: (reference) =>
              reference.dataset.tooltip || reference.dataset.popover,
          });
        }
      });
    });
  },
};
