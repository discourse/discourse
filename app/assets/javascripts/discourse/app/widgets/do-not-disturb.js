import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import { publishDoNotDisturbOffFor } from "discourse/lib/do-not-disturb";
import showModal from "discourse/lib/show-modal";

export default createWidget("do-not-disturb", {
  tagName: "div.btn.do-not-disturb-btn",

  html() {
    if (this.currentUser.do_not_disturb_until) {
      let remainingTime = moment()
        .to(moment(this.currentUser.do_not_disturb_until))
        .split("in ")[1];
      return [
        iconNode("far-moon"),
        h("span#do-not-disturb-link", I18n.t("do_not_disturb.unpause")),
        h(
          "span#do-not-disturb-time-remaining",
          I18n.t("do_not_disturb.remaining", { remaining: remainingTime })
        ),
      ];
    } else {
      return [
        iconNode("far-moon"),
        h("span#do-not-disturb-link", I18n.t("do_not_disturb.pause")),
      ];
    }
  },

  click() {
    if (this.currentUser.do_not_disturb_until) {
      publishDoNotDisturbOffFor(this.currentUser).then(() => {
        this.scheduleRerender();
      });
    } else {
      showModal("do-not-disturb");
    }
  },
});
