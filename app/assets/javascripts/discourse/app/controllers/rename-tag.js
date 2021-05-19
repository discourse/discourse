import { action } from "@ember/object";
import BufferedContent from "discourse/mixins/buffered-content";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, BufferedContent, {
  newTag: null,

  @discourseComputed("newTag", "model.id")
  renameDisabled(newTag, currentTag) {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    newTag = newTag ? newTag.replace(filterRegexp, "").trim() : "";
    return newTag.length === 0 || newTag === currentTag;
  },

  @action
  performRename() {
    this.model
      .update({ id: this.newTag })
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
});
