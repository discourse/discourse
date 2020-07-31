import I18n from "I18n";
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

export default Controller.extend(ModalFunctionality, {
  imageUrl: null,
  local: equal("selection", "local"),
  remote: equal("selection", "remote"),
  selection: "local",

  uploadTranslate(key) {
    if (allowsAttachments(this.currentUser.staff, this.siteSettings)) {
      key += "_with_attachments";
    }
    return `upload_selector.${key}`;
  },

  @discourseComputed()
  uploadIcon() {
    return uploadIcon(this.currentUser.staff, this.siteSettings);
  },

  @discourseComputed()
  title() {
    return this.uploadTranslate("title");
  },

  @discourseComputed("selection")
  tip(selection) {
    const authorized_extensions = authorizesAllExtensions(
      this.currentUser.staff,
      this.siteSettings
    )
      ? ""
      : `(${authorizedExtensions(this.currentUser.staff, this.siteSettings)})`;
    return I18n.t(this.uploadTranslate(`${selection}_tip`), {
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
