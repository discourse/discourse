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
        h("div.do-not-disturb-inner-container", [
          h("div.do-not-disturb-background", iconNode("moon")),

          h("span.do-not-disturb-label", [
            h("span", I18n.t("do_not_disturb.label")),
            h(
              "span.time-remaining",
              I18n.t("do_not_disturb.remaining", { remaining: remainingTime })
            ),
          ]),
        ]),
      ];
    } else {
      return [
        iconNode("far-moon"),
        h("span.do-not-disturb-label", I18n.t("do_not_disturb.label")),
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
