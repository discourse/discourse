import Helper from "@ember/component/helper";
import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";

export default class DispositionIcon extends Helper {
  compute([disposition]) {
    if (!disposition) {
      return null;
    }
    let icon;
    let title = "admin.flags.dispositions." + disposition;
    switch (disposition) {
      case "deferred": {
        icon = "up-right-from-square";
        break;
      }
      case "agreed": {
        icon = "thumbs-o-up";
        break;
      }
      case "disagreed": {
        icon = "thumbs-o-down";
        break;
      }
    }
    return htmlSafe(iconHTML(icon, { title }));
  }
}
