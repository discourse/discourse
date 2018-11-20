import ModalFunctionality from "discourse/mixins/modal-functionality";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Mixin.create(ModalFunctionality, {
  reason: null,
  message: null,
  postEdit: null,
  postAction: null,
  user: null,
  post: null,
  successCallback: null,

  resetModal() {
    this.setProperties({
      reason: null,
      message: null,
      loadingUser: true,
      post: null,
      postEdit: null,
      postAction: "delete",
      before: null,
      successCallback: null
    });
  },

  penalize(cb) {
    let before = this.get("before");
    let promise = before ? before() : Ember.RSVP.resolve();

    return promise
      .then(() => cb())
      .then(result => {
        this.send("closeModal");
        let callback = this.get("successCallback");
        if (callback) {
          callback(result);
        }
      })
      .catch(popupAjaxError);
  }
});
