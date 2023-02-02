import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { dateNode } from "discourse/helpers/node";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import showModal from "discourse/lib/show-modal";
import DoNotDisturb from "discourse/lib/do-not-disturb";

export default createWidget("do-not-disturb", {
  tagName: "li.do-not-disturb",
  saving: false,

  html() {
    const isOn = this.currentUser.isInDoNotDisturb();
    return [this._menuButton(isOn)];
  },

  click() {
    if (this.saving) {
      return;
    }

    this.saving = true;
    if (this.currentUser.do_not_disturb_until) {
      return this.currentUser.leaveDoNotDisturb().then(() => {
        this.saving = false;
      });
    } else {
      this.saving = false;
      return showModal("do-not-disturb");
    }
  },

  _menuButton(isOn) {
    const icon = iconNode(isOn ? "toggle-on" : "toggle-off");
    return h("button.btn-flat.do-not-disturb-inner-container", [
      icon,
      this._label(),
    ]);
  },

  _label() {
    const content = [h("span", I18n.t("pause_notifications.label"))];

    const until = this.currentUser.do_not_disturb_until;
    if (!DoNotDisturb.isEternal(until)) {
      content.push(dateNode(until));
    }

    return h("span.do-not-disturb-label", content);
  },
});
