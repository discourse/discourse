import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import $ from "jquery";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse-common/lib/debounce";
import getURL from "discourse-common/lib/get-url";
import { convertIconClass } from "discourse-common/lib/icon-library";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@classNames("group-flair-inputs")
export default class GroupFlairInputs extends Component {
  @discourseComputed
  demoAvatarUrl() {
    return getURL("/images/avatar.png");
  }

  @discourseComputed("model.flair_type")
  flairPreviewIcon(flairType) {
    return flairType && flairType === "icon";
  }

  @discourseComputed("model.flair_icon")
  flairPreviewIconUrl(flairIcon) {
    return flairIcon ? convertIconClass(flairIcon) : "";
  }

  @on("didInsertElement")
  @observes("model.flair_icon")
  _loadSVGIcon(flairIcon) {
    if (flairIcon) {
      discourseDebounce(this, this._loadIcon, 1000);
    }
  }

  _loadIcon() {
    if (!this.model.flair_icon) {
      return;
    }

    const icon = convertIconClass(this.model.flair_icon),
      c = "#svg-sprites",
      h = "ajax-icon-holder",
      singleIconEl = `${c} .${h}`;

    if (!icon) {
      return;
    }

    if (!$(`${c} symbol#${icon}`).length) {
      ajax(`/svg-sprite/search/${icon}`).then(function (data) {
        if ($(singleIconEl).length === 0) {
          $(c).append(`<div class="${h}">`);
        }

        $(singleIconEl).html(
          `<svg xmlns='http://www.w3.org/2000/svg' style='display: none;'>${data}</svg>`
        );
      });
    }
  }

  @discourseComputed("model.flair_type")
  flairPreviewImage(flairType) {
    return flairType && flairType === "image";
  }

  @discourseComputed("model.flair_url")
  flairImageUrl(flairUrl) {
    return flairUrl && flairUrl.includes("/") ? flairUrl : null;
  }

  @discourseComputed("flairPreviewImage")
  flairPreviewLabel(flairPreviewImage) {
    const key = flairPreviewImage ? "image" : "icon";
    return i18n(`groups.flair_preview_${key}`);
  }

  @action
  setFlairImage(upload) {
    this.model.setProperties({
      flair_url: getURL(upload.url),
      flair_upload_id: upload.id,
    });
  }

  @action
  removeFlairImage() {
    this.model.setProperties({
      flair_url: null,
      flair_upload_id: null,
    });
  }
}
