import { next } from "@ember/runloop";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";

export default Controller.extend(ModalFunctionality, {
  expanded: false,

  onShow() {
    ajax(
      userPath(`${this.get("currentUser.username_lower")}/activity.json`)
    ).then(posts => {
      if (posts.length > 0) {
        this.set("latest_post", posts[0]);
      }
    });
  },

  actions: {
    toggleExpanded() {
      this.set("expanded", !this.expanded);
    },

    highlightSecure() {
      this.send("closeModal");

      next(() => {
        const $prefPasswordDiv = $(".pref-password");

        $prefPasswordDiv.addClass("highlighted");
        $prefPasswordDiv.on("animationend", () =>
          $prefPasswordDiv.removeClass("highlighted")
        );

        window.scrollTo({
          top: $prefPasswordDiv.offset().top,
          behavior: "smooth"
        });
      });
    }
  }
});
