import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";

export default Ember.Controller.extend(ModalFunctionality, {
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
      this.set("expanded", !this.get("expanded"));
    },

    highlightSecure() {
      this.send("closeModal");

      Ember.run.next(() => {
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
