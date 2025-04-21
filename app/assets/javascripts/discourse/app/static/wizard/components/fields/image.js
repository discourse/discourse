import Component from "@ember/component";
import { warn } from "@ember/debug";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { classNames } from "@ember-decorators/component";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import discourseComputed from "discourse/lib/decorators";
import getUrl from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import imagePreviews from "./image-previews";

@classNames("wizard-container__image-upload")
export default class Image extends Component {
  @service dialog;

  uploading = false;

  @discourseComputed("field.id")
  previewComponent(id) {
    return imagePreviews[dasherize(id)] ?? imagePreviews.generic;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.setupUploads();
  }

  @discourseComputed("uploading", "field.value")
  hasUpload() {
    return (
      !this.uploading &&
      this.field.value &&
      !this.field.value.includes("discourse-logo-sketch-small.png")
    );
  }

  setupUploads() {
    const id = this.field.id;
    this._uppyInstance = new Uppy({
      id: `wizard-field-image-${id}`,
      meta: { upload_type: `wizard_${id}` },
      autoProceed: true,
    });

    this._uppyInstance.use(XHRUpload, {
      endpoint: getUrl("/uploads.json"),
      headers: {
        "X-CSRF-Token": this.session.csrfToken,
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
      let message = i18n("wizard.upload_error");
      if (response.body.errors) {
        message = response.body.errors.join("\n");
      }

      this.dialog.alert(message);
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
  }
}
