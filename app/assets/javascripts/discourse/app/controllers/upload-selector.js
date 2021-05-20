import {
  allowsAttachments,
  authorizedExtensions,
  uploadIcon,
} from "discourse/lib/uploads";
import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, {
  imageUrl: null,
  local: equal("selection", "local"),
  remote: equal("selection", "remote"),
  selection: "local",

  @discourseComputed()
  allowAdditionalFormats() {
    return allowsAttachments(this.currentUser.staff, this.siteSettings);
  },

  @discourseComputed()
  uploadIcon() {
    return uploadIcon(this.currentUser.staff, this.siteSettings);
  },

  @discourseComputed("allowAdditionalFormats")
  title(allowAdditionalFormats) {
    const suffix = allowAdditionalFormats ? "_with_attachments" : "";
    return `upload_selector.title${suffix}`;
  },

  @discourseComputed("selection", "allowAdditionalFormats")
  tip(selection, allowAdditionalFormats) {
    const suffix = allowAdditionalFormats ? "_with_attachments" : "";
    return I18n.t(`upload_selector.${selection}_tip${suffix}`);
  },

  @discourseComputed()
  supportedFormats() {
    const extensions = authorizedExtensions(
      this.currentUser.staff,
      this.siteSettings
    );

    return `(${extensions})`;
  },

  actions: {
    upload() {
      if (this.local) {
        $(".wmd-controls").fileupload("add", {
          fileInput: $("#filename-input"),
        });
      } else {
        const imageUrl = this.imageUrl || "";
        const toolbarEvent = this.toolbarEvent;

        if (imageUrl.match(/\.(jpg|jpeg|png|gif|heic|heif|webp)$/)) {
          toolbarEvent.addText(`![](${imageUrl})`);
        } else {
          toolbarEvent.addText(imageUrl);
        }
      }
      this.send("closeModal");
    },
  },
});
