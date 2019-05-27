import ModalFunctionality from "discourse/mixins/modal-functionality";
import computed from "ember-addons/ember-computed-decorators";
import BufferedContent from "discourse/mixins/buffered-content";
import { extractError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend(ModalFunctionality, BufferedContent, {
  @computed("buffered.id", "id")
  renameDisabled(inputTagName, currentTagName) {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g"),
      newTagName = inputTagName
        ? inputTagName.replace(filterRegexp, "").trim()
        : "";

    return newTagName.length === 0 || newTagName === currentTagName;
  },

  actions: {
    performRename() {
      const tag = this.model,
        self = this;
      tag
        .update({ id: this.get("buffered.id") })
        .then(function(result) {
          self.send("closeModal");
          if (result.responseJson.tag) {
            self.transitionToRoute("tags.show", result.responseJson.tag.id);
          } else {
            self.flash(extractError(result.responseJson.errors[0]), "error");
          }
        })
        .catch(function(error) {
          self.flash(extractError(error), "error");
        });
    }
  }
});
