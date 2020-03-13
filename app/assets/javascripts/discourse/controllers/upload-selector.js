import { equal } from "@ember/object/computed";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import {
  allowsAttachments,
  authorizedExtensions,
  authorizesAllExtensions,
  uploadIcon
} from "discourse/lib/uploads";

function uploadTranslate(key, user) {
  if (allowsAttachments(user.staff)) {
    key += "_with_attachments";
  }
  return `upload_selector.${key}`;
}

export default Controller.extend(ModalFunctionality, {
  imageUrl: null,
  local: equal("selection", "local"),
  remote: equal("selection", "remote"),
  selection: "local",

  @discourseComputed()
  uploadIcon() {
    return uploadIcon(this.currentUser.staff);
  },

  @discourseComputed()
  title() {
    return uploadTranslate("title", this.currentUser);
  },

  @discourseComputed("selection")
  tip(selection) {
    const authorized_extensions = authorizesAllExtensions(
      this.currentUser.staff
    )
      ? ""
      : `(${authorizedExtensions(this.currentUser.staff)})`;
    return I18n.t(uploadTranslate(`${selection}_tip`, this.currentUser), {
      authorized_extensions
    });
  },

  actions: {
    upload() {
      if (this.local) {
        $(".wmd-controls").fileupload("add", {
          fileInput: $("#filename-input")
        });
      } else {
        const imageUrl = this.imageUrl || "";
        const toolbarEvent = this.toolbarEvent;

        if (imageUrl.match(/\.(jpg|jpeg|png|gif)$/)) {
          toolbarEvent.addText(`![](${imageUrl})`);
        } else {
          toolbarEvent.addText(imageUrl);
        }
      }
      this.send("closeModal");
    }
  }
});
