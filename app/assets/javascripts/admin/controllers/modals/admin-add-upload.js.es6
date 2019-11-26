import { isEmpty } from "@ember/utils";
import { and, not } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import showModal from "discourse/lib/show-modal";
import {
  default as discourseComputed,
  observes
} from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

const THEME_FIELD_VARIABLE_TYPE_IDS = [2, 3, 4];

const SCSS_VARIABLE_NAMES = [
  // common/foundation/colors.scss
  "primary",
  "secondary",
  "tertiary",
  "quaternary",
  "header_background",
  "header_primary",
  "highlight",
  "danger",
  "success",
  "love",
  // common/foundation/math.scss
  "E",
  "PI",
  "LN2",
  "SQRT2",
  // common/foundation/variables.scss
  "small-width",
  "medium-width",
  "large-width",
  "google",
  "instagram",
  "facebook",
  "cas",
  "twitter",
  "github",
  "base-font-size",
  "base-line-height",
  "base-font-family",
  "primary-low",
  "primary-medium",
  "secondary-low",
  "secondary-medium",
  "tertiary-low",
  "quaternary-low",
  "highlight-low",
  "highlight-medium",
  "danger-low",
  "danger-medium",
  "success-low",
  "love-low"
];

export default Controller.extend(ModalFunctionality, {
  adminCustomizeThemesShow: inject(),

  uploadUrl: "/admin/themes/upload_asset",

  onShow() {
    this.set("name", null);
    this.set("fileSelected", false);
  },

  enabled: and("nameValid", "fileSelected"),
  disabled: not("enabled"),

  @discourseComputed("name", "adminCustomizeThemesShow.model.theme_fields")
  errorMessage(name, themeFields) {
    if (name) {
      if (!name.match(/^[a-z_][a-z0-9_-]*$/i)) {
        return I18n.t(
          "admin.customize.theme.variable_name_error.invalid_syntax"
        );
      } else if (SCSS_VARIABLE_NAMES.includes(name.toLowerCase())) {
        return I18n.t("admin.customize.theme.variable_name_error.no_overwrite");
      } else if (
        themeFields.some(
          tf =>
            THEME_FIELD_VARIABLE_TYPE_IDS.includes(tf.type_id) &&
            name === tf.name
        )
      ) {
        return I18n.t(
          "admin.customize.theme.variable_name_error.must_be_unique"
        );
      }
    }

    return null;
  },

  @discourseComputed("errorMessage")
  nameValid(errorMessage) {
    return null === errorMessage;
  },

  @observes("name")
  uploadChanged() {
    const file = $("#file-input")[0];
    this.set("fileSelected", file && file.files[0]);
  },

  actions: {
    updateName() {
      let name = this.name;
      if (isEmpty(name)) {
        name = $("#file-input")[0].files[0].name;
        this.set("name", name.split(".")[0]);
      }
      this.uploadChanged();
    },

    upload() {
      const file = $("#file-input")[0].files[0];

      const options = {
        type: "POST",
        processData: false,
        contentType: false,
        data: new FormData()
      };

      options.data.append("file", file);
      this.send("postUpload", options);
    },

    postUpload(options, markUploadInsecure = false) {
      if (markUploadInsecure) {
        options.data.append("mark_upload_insecure", true);
      }

      ajax(this.uploadUrl, options)
        .then(result => {
          if (result.prompt_mark_insecure) {
            return this.send("promptMarkUploadInsecure", options);
          }

          const upload = {
            upload_id: result.upload_id,
            name: this.name,
            original_filename: options.data.get("file").name
          };
          this.adminCustomizeThemesShow.send("addUpload", upload);
          this.send("closeModal");
        })
        .catch(e => {
          popupAjaxError(e);
        });
    },

    promptMarkUploadInsecure(uploadAjaxOptions) {
      this.send("closeModal");
      return bootbox.confirm(
        I18n.t("uploads.prompt_mark_insecure"),
        I18n.t("uploads.no_leave_secure"),
        I18n.t("uploads.yes_mark_insecure"),
        result => {
          if (result) {
            return this.send("postUpload", uploadAjaxOptions, true);
          }
          showModal("admin-add-upload", { admin: true, name: "" });
        }
      );
    }
  }
});
