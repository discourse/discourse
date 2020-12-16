import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import showModal from "discourse/lib/show-modal";

export default createWidget("do-not-disturb", {
  tagName: "div.btn.do-not-disturb-btn",
  saving: false,

  html() {
    if (this.currentUser.isInDoNotDisturb()) {
      let remainingTime = moment()
        .to(moment(this.currentUser.do_not_disturb_until))
        .split(" ")
        .slice(1)
        .join(" "); // The first word is "in" and we don't want that.
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
    if (this.saving) {
      return;
    }

    this.saving = true;
    if (this.currentUser.do_not_disturb_until) {
      return this.currentUser.leaveDoNotDisturb();
    } else {
      return showModal("do-not-disturb");
    }
    this.saving = false;
  },
});
