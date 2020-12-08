import BufferedContent from "discourse/mixins/buffered-content";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import { oneWay } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, BufferedContent, {
  tagId: oneWay("model.id"),

  @discourseComputed("tagId", "model.id")
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
        .update({ id: this.get("tagId") })
        .then((result) => {
          this.send("closeModal");

          if (result.responseJson.tag) {
            this.transitionToRoute("tag.show", result.responseJson.tag.id);
          } else {
            this.flash(extractError(result.responseJson.errors[0]), "error");
          }
        })
        .catch((error) => this.flash(extractError(error), "error"));
    },
  },
});
