import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
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

  enabled: Ember.computed.and("nameValid", "fileSelected"),
  disabled: Ember.computed.not("enabled"),

  @computed("name", "adminCustomizeThemesShow.model.theme_fields")
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

  @computed("errorMessage")
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
      if (Ember.isEmpty(name)) {
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

      ajax(this.uploadUrl, options)
        .then(result => {
          const upload = {
            upload_id: result.upload_id,
            name: this.name,
            original_filename: file.name
          };
          this.adminCustomizeThemesShow.send("addUpload", upload);
          this.send("closeModal");
        })
        .catch(e => {
          popupAjaxError(e);
        });
    }
  }
});
