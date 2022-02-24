import Controller from "@ember/controller";
import { schedule } from "@ember/runloop";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import highlightSyntax from "discourse/lib/highlight-syntax";

export default Controller.extend(ModalFunctionality, {
  onShow() {
    schedule("afterRender", () => {
      highlightSyntax(
        document.querySelector(".modal-body"),
        this.siteSettings,
        this.session
      );
    });
  },
});
