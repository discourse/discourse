import deprecated from "discourse/lib/deprecated";

export function showPopover() {
  deprecated("`showPopover` is deprecated. Use tooltip service instead.", {
    id: "discourse.show-popover",
  });
}

export function hidePopover() {
  deprecated("`hidePopover` is deprecated. Use tooltip service instead.", {
    id: "discourse.hide-popover",
  });
}
