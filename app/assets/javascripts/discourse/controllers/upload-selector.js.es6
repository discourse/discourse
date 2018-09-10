import ModalFunctionality from "discourse/mixins/modal-functionality";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import {
  allowsAttachments,
  authorizesAllExtensions,
  authorizedExtensions,
  uploadIcon
} from "discourse/lib/utilities";

function uploadTranslate(key) {
  if (allowsAttachments()) {
    key += "_with_attachments";
  }
  return `upload_selector.${key}`;
}

export default Ember.Controller.extend(ModalFunctionality, {
  showMore: false,
  imageUrl: null,
  imageLink: null,
  local: Ember.computed.equal("selection", "local"),
  remote: Ember.computed.equal("selection", "remote"),
  selection: "local",

  @computed()
  uploadIcon: () => uploadIcon(),

  @computed()
  title: () => uploadTranslate("title"),

  @computed("selection")
  tip(selection) {
    const authorized_extensions = authorizesAllExtensions()
      ? ""
      : `(${authorizedExtensions()})`;
    return I18n.t(uploadTranslate(`${selection}_tip`), {
      authorized_extensions
    });
  },

  @observes("selection")
  _selectionChanged() {
    if (this.get("local")) {
      this.set("showMore", false);
    }
  },

  actions: {
    upload() {
      if (this.get("local")) {
        $(".wmd-controls").fileupload("add", {
          fileInput: $("#filename-input")
        });
      } else {
        const imageUrl = this.get("imageUrl") || "";
        const imageLink = this.get("imageLink") || "";
        const toolbarEvent = this.get("toolbarEvent");

        if (this.get("showMore") && imageLink.length > 3) {
          toolbarEvent.addText(`[![](${imageUrl})](${imageLink})`);
        } else if (imageUrl.match(/\.(jpg|jpeg|png|gif)$/)) {
          toolbarEvent.addText(`![](${imageUrl})`);
        } else {
          toolbarEvent.addText(imageUrl);
        }
      }
      this.send("closeModal");
    },

    toggleShowMore() {
      this.toggleProperty("showMore");
    }
  }
});
