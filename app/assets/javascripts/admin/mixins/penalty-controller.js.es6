import ModalFunctionality from "discourse/mixins/modal-functionality";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Mixin from "@ember/object/mixin";
import { Promise } from "rsvp";

export default Mixin.create(ModalFunctionality, {
  reason: null,
  message: null,
  postEdit: null,
  postAction: null,
  user: null,
  postId: null,
  successCallback: null,

  resetModal() {
    this.setProperties({
      reason: null,
      message: null,
      loadingUser: true,
      postId: null,
      postEdit: null,
      postAction: "delete",
      before: null,
      successCallback: null
    });
  },

  penalize(cb) {
    let before = this.before;
    let promise = before ? before() : Promise.resolve();

    return promise
      .then(() => cb())
      .then(result => {
        this.send("closeModal");
        let callback = this.successCallback;
        if (callback) {
          callback(result);
        }
      })
      .catch(popupAjaxError);
  }
});
