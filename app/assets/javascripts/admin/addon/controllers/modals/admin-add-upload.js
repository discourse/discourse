import { action } from "@ember/object";
import { and, not } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { isEmpty } from "@ember/utils";
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
  "love-low",
];

export default class AdminAddUploadController extends Controller.extend(
  ModalFunctionality
) {
  @controller adminCustomizeThemesShow;

  uploadUrl = "/admin/themes/upload_asset";

  @and("nameValid", "fileSelected") enabled;
  @not("enabled") disabled;
  onShow() {
    this.set("name", null);
    this.set("fileSelected", false);
  }

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
          (tf) =>
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
  }

  @discourseComputed("errorMessage")
  nameValid(errorMessage) {
    return null === errorMessage;
  }

  @observes("name")
  uploadChanged() {
    const file = $("#file-input")[0];
    this.set("fileSelected", file && file.files[0]);
  }

  @action
  updateName() {
    let name = this.name;
    if (isEmpty(name)) {
      name = $("#file-input")[0].files[0].name;
      this.set("name", name.split(".")[0]);
    }
    this.uploadChanged();
  }

  @action
  upload() {
    const file = $("#file-input")[0].files[0];

    const options = {
      type: "POST",
      processData: false,
      contentType: false,
      data: new FormData(),
    };

    options.data.append("file", file);

    ajax(this.uploadUrl, options)
      .then((result) => {
        const upload = {
          upload_id: result.upload_id,
          name: this.name,
          original_filename: file.name,
        };
        this.adminCustomizeThemesShow.send("addUpload", upload);
        this.send("closeModal");
      })
      .catch((e) => {
        popupAjaxError(e);
      });
  }
}
