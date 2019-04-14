import ModalFunctionality from "discourse/mixins/modal-functionality";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(ModalFunctionality, {
  post: null,
  resolve: null,
  reject: null,

  notice: null,
  saving: false,

  @computed("saving", "notice")
  disabled(saving, notice) {
    return saving || Ember.isEmpty(notice);
  },

  onShow() {
    this.setProperties({
      notice: "",
      saving: false
    });
  },

  onClose() {
    const reject = this.get("reject");
    if (reject) {
      reject();
    }
  },

  actions: {
    setNotice() {
      this.set("saving", true);

      const post = this.get("post");
      const resolve = this.get("resolve");
      const reject = this.get("reject");
      const notice = this.get("notice");

      // Let `updatePostField` handle state.
      this.setProperties({ resolve: null, reject: null });

      post
        .updatePostField("notice", notice)
        .then(() => {
          post.setProperties({
            notice_type: "custom",
            notice_args: notice
          });
          resolve();
          this.send("closeModal");
        })
        .catch(() => {
          reject();
          this.send("closeModal");
        });
    }
  }
});
