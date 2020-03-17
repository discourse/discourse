import { iconHTML } from "discourse-common/lib/icon-library";
import Helper from "@ember/component/helper";

export default Helper.extend({
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
    return iconHTML(icon, { title }).htmlSafe();
  }
});
