import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import showModal from "discourse/lib/show-modal";

export default createWidget("do-not-disturb", {
  tagName: "div.btn.do-not-disturb-btn",

  html() {
    if (this.currentUser.do_not_disturb_until) {
      let remainingTime = moment()
        .to(moment(this.currentUser.do_not_disturb_until))
        .split("in ")[1];
      return [
        iconNode("discourse-snooze"),
        h("span#do-not-disturb-link", I18n.t("do_not_disturb.unpause")),
        h(
          "span#do-not-disturb-time-remaining",
          I18n.t("do_not_disturb.remaining", { remaining: remainingTime })
        ),
      ];
    } else {
      return [
        iconNode("discourse-snooze"),
        h("span#do-not-disturb-link", I18n.t("do_not_disturb.pause")),
      ];
    }
  },

  click() {
    if (this.currentUser.do_not_disturb_until) {
      ajax({
        url: "/do-not-disturb",
        type: "DELETE",
      }).then(() => {
        this.currentUser.set("do_not_disturb_until", false);
        this.scheduleRerender();
      });
    } else {
      showModal("do-not-disturb");
    }
  },
});
