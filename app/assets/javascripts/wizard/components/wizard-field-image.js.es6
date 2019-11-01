import Component from "@ember/component";
import getUrl from "discourse-common/lib/get-url";
import computed from "ember-addons/ember-computed-decorators";
import { getToken } from "wizard/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";

export default Component.extend({
  classNames: ["wizard-image-row"],
  uploading: false,

  @computed("field.id")
  previewComponent(id) {
    const componentName = `image-preview-${Ember.String.dasherize(id)}`;
    const exists = getOwner(this).lookup(`component:${componentName}`);
    return exists ? componentName : "wizard-image-preview";
  },

  didInsertElement() {
    this._super(...arguments);

    const $upload = $(this.element);

    const id = this.get("field.id");

    $upload.fileupload({
      url: getUrl("/uploads.json"),
      formData: {
        synchronous: true,
        type: `wizard_${id}`,
        authenticity_token: getToken()
      },
      dataType: "json",
      dropZone: $upload
    });

    $upload.on("fileuploadsubmit", () => this.set("uploading", true));

    $upload.on("fileuploaddone", (e, response) => {
      this.set("field.value", response.result.url);
      this.set("uploading", false);
    });

    $upload.on("fileuploadfail", (e, response) => {
      let message = I18n.t("wizard.upload_error");
      if (response.jqXHR.responseJSON && response.jqXHR.responseJSON.errors) {
        message = response.jqXHR.responseJSON.errors.join("\n");
      }

      window.swal({
        customClass: "wizard-warning",
        title: "",
        text: message,
        type: "warning",
        confirmButtonColor: "#6699ff"
      });
      this.set("uploading", false);
    });
  }
});
