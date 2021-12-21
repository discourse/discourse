import Component from "@ember/component";
import { warn } from "@ember/debug";
import I18n from "I18n";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse-common/utils/decorators";
import { getOwner } from "discourse-common/lib/get-owner";
import { getToken } from "wizard/lib/ajax";
import getUrl from "discourse-common/lib/get-url";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";

export default Component.extend({
  classNames: ["wizard-image-row"],
  uploading: false,

  @discourseComputed("field.id")
  previewComponent(id) {
    const componentName = `image-preview-${dasherize(id)}`;
    const exists = getOwner(this).lookup(`component:${componentName}`);
    return exists ? componentName : "wizard-image-preview";
  },

  didInsertElement() {
    this._super(...arguments);
    this.setupUploads();
  },

  setupUploads() {
    const id = this.get("field.id");
    this._uppyInstance = new Uppy({
      id: `wizard-field-image-${id}`,
      meta: { upload_type: `wizard_${id}` },
      autoProceed: true,
    });

    this._uppyInstance.use(XHRUpload, {
      endpoint: getUrl("/uploads.json"),
      headers: {
        "X-CSRF-Token": getToken(),
      },
    });

    this._uppyInstance.use(DropTarget, { target: this.element });

    this._uppyInstance.on("upload", () => {
      this.set("uploading", true);
    });

    this._uppyInstance.on("upload-success", (file, response) => {
      this.set("field.value", response.body.url);
      this.set("uploading", false);
    });

    this._uppyInstance.on("upload-error", (file, error, response) => {
      let message = I18n.t("wizard.upload_error");
      if (response.body.errors) {
        message = response.body.errors.join("\n");
      }

      window.bootbox.alert(message);
      this.set("uploading", false);
    });

    this.element
      .querySelector(".wizard-hidden-upload-field")
      .addEventListener("change", (event) => {
        const files = Array.from(event.target.files);
        files.forEach((file) => {
          try {
            this._uppyInstance.addFile({
              source: `${this.id} file input`,
              name: file.name,
              type: file.type,
              data: file,
            });
          } catch (err) {
            warn(`error adding files to uppy: ${err}`, {
              id: "discourse.upload.uppy-add-files-error",
            });
          }
        });
      });
  },
});
