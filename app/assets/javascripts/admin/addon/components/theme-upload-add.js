import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

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

export default class ThemeUploadAdd extends Component {
  @tracked name;
  @tracked fileSelected = false;
  @tracked flash;

  uploadUrl = this.args.model.uploadUrl || "/admin/themes/upload_asset";

  get disabled() {
    return this.errorMessage && this.fileSelected;
  }

  get errorMessage() {
    if (!this.name) {
      return;
    } else if (!this.name.match(/^[a-z_][a-z0-9_-]*$/i)) {
      return i18n("admin.customize.theme.variable_name_error.invalid_syntax");
    } else if (SCSS_VARIABLE_NAMES.includes(name.toLowerCase())) {
      return i18n("admin.customize.theme.variable_name_error.no_overwrite");
    } else if (
      this.args.model.themeFields.some(
        (tf) =>
          THEME_FIELD_VARIABLE_TYPE_IDS.includes(tf.type_id) &&
          this.name === tf.name
      )
    ) {
      return i18n("admin.customize.theme.variable_name_error.must_be_unique");
    }
  }

  @action
  updateName(e) {
    if (isEmpty(this.name)) {
      this.name = e.target.files[0].name.split(".")[0];
    }
    this.fileSelected = e.target.files[0];
  }

  @action
  async upload() {
    const file = document.getElementById("file-input").files[0];
    const options = {
      type: "POST",
      processData: false,
      contentType: false,
      data: new FormData(),
    };
    options.data.append("file", file);

    try {
      const result = await ajax(this.uploadUrl, options);
      const upload = {
        upload_id: result.upload_id,
        name: this.name,
        original_filename: file.name,
      };
      this.args.model.addUpload(upload);
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }
}
