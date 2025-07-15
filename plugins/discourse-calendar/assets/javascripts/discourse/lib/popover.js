import { createPopper } from "@popperjs/core";

let eventPopper;
const EVENT_POPOVER_ID = "event-popover";

export function buildPopover(jsEvent, htmlContent) {
  const node = document.createElement("div");
  node.setAttribute("id", EVENT_POPOVER_ID);
  node.innerHTML = htmlContent;

  const arrow = document.createElement("span");
  arrow.dataset.popperArrow = true;
  node.appendChild(arrow);
  document.body.appendChild(node);

  eventPopper = createPopper(
    jsEvent.target,
    document.getElementById(EVENT_POPOVER_ID),
    {
      placement: "bottom",
      modifiers: [
        {
          name: "arrow",
        },
        {
          name: "offset",
          options: {
            offset: [20, 10],
          },
        },
      ],
    }
  );
}

export function destroyPopover() {
  eventPopper?.destroy();
  document.getElementById(EVENT_POPOVER_ID)?.remove();
}
