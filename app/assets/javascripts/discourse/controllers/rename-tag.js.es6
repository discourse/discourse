import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import computed from "ember-addons/ember-computed-decorators";
import BufferedContent from "discourse/mixins/buffered-content";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, BufferedContent, {
  @computed("buffered.id", "id")
  renameDisabled(inputTagName, currentTagName) {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    const newTagName = inputTagName
      ? inputTagName.replace(filterRegexp, "").trim()
      : "";

    return newTagName.length === 0 || newTagName === currentTagName;
  },

  actions: {
    performRename() {
      this.model
        .update({ id: this.get("buffered.id") })
        .then(result => {
          this.send("closeModal");

          if (result.responseJson.tag) {
            this.transitionToRoute("tags.show", result.responseJson.tag.id);
          } else {
            this.flash(extractError(result.responseJson.errors[0]), "error");
          }
        })
        .catch(error => this.flash(extractError(error), "error"));
    }
  }
});
