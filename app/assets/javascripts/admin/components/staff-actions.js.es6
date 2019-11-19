import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";

export default Component.extend({
  classNames: ["table", "staff-actions"],

  willDestroyElement() {
    $(this.element).off("click.discourse-staff-logs");
  },

  didInsertElement() {
    this._super(...arguments);

    $(this.element).on(
      "click.discourse-staff-logs",
      "[data-link-post-id]",
      e => {
        let postId = $(e.target).attr("data-link-post-id");

        this.store.find("post", postId).then(p => {
          DiscourseURL.routeTo(p.get("url"));
        });
        return false;
      }
    );
  }
});
