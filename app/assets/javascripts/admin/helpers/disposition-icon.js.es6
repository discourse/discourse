import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Helper.extend({
  compute([disposition]) {
    if (!disposition) {
      return null;
    }
    let icon;
    let title = "admin.flags.dispositions." + disposition;
    switch (disposition) {
      case "deferred": {
        icon = "external-link";
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
