import computed from "ember-addons/ember-computed-decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  saved: false,
  isSaving: false,
  buffer: null,

  @computed("buffer", "model.content")
  saveDisabled(buffer, orig) {
    return buffer === orig;
  },

  revertDisbaled: Ember.computed.not("model.overridden"),

  actions: {
    save(content = this.buffer) {
      this.setProperties({
        isSaving: true,
        saved: false
      });

      ajax("robots.json", {
        method: "PUT",
        data: { content }
      })
        .then(model => {
          this.setProperties({
            saved: true,
            model: model,
            buffer: model.content
          });
        })
        .finally(() => {
          this.set("isSaving", false);
        });
    },

    revert() {
      this.send("save", "");
    }
  }
});
