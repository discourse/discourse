import deprecated from "discourse-common/lib/deprecated";

export function showPopover() {
  deprecated("`showPopover` is deprecated. Use tooltip service instead.", {
    id: "show-popover",
  });
}

export function hidePopover() {
  deprecated("`hidePopover` is deprecated. Use tooltip service instead.", {
    id: "hide-popover",
  });
}
