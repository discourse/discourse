import Helper from "@ember/component/helper";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

export default class DispositionIcon extends Helper {
  compute([disposition]) {
    if (!disposition) {
      return null;
    }
    let icon;
    let title = "admin.flags.dispositions." + disposition;
    switch (disposition) {
      case "deferred": {
        icon = "external-link-alt";
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
