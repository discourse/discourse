import BaseCustomSidebarButton from "discourse/lib/sidebar/base-custom-sidebar-button";

export const topSidebarButtons = [];
export const bottomSidebarButtons = [];

export function addSidebarButton(position, func) {
  if (position === "top") {
    topSidebarButtons.push(func.call(this, BaseCustomSidebarButton));
  } else {
    bottomSidebarButtons.push(func.call(this, BaseCustomSidebarButton));
  }
}
