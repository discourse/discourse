/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import $ from "jquery";
import AvatarFlair from "discourse/components/avatar-flair";
import RadioButton from "discourse/components/radio-button";
import TextField from "discourse/components/text-field";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import getURL from "discourse/lib/get-url";
import { convertIconClass } from "discourse/lib/icon-library";
import IconPicker from "discourse/select-kit/components/icon-picker";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

@classNames("group-flair-inputs")
export default class GroupFlairInputs extends Component {
  @computed
  get demoAvatarUrl() {
    return getURL("/images/avatar.png");
  }

  @computed("model.flair_type")
  get flairPreviewIcon() {
    return this.model?.flair_type && this.model?.flair_type === "icon";
  }

  @computed("model.flair_icon")
  get flairPreviewIconUrl() {
    return this.model?.flair_icon ? convertIconClass(this.model?.flair_icon) : "";
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

  @computed("model.flair_type")
  get flairPreviewImage() {
    return this.model?.flair_type && this.model?.flair_type === "image";
  }

  @computed("model.flair_url")
  get flairImageUrl() {
    return this.model?.flair_url && this.model?.flair_url?.includes("/") ? this.model?.flair_url : null;
  }

  @computed("flairPreviewImage")
  get flairPreviewLabel() {
    const key = this.flairPreviewImage ? "image" : "icon";
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

  <template>
    <div class="control-group">
      <label class="control-label" for="flair_url">{{i18n
          "groups.flair_url"
        }}</label>

      <div class="radios">
        <label class="radio-label" for="avatar-flair-icon">
          <RadioButton
            @name="avatar-flair-icon"
            @id="avatar-flair-icon"
            @value="icon"
            @selection={{this.model.flair_type}}
          />
          {{i18n "groups.flair_type.icon"}}
        </label>

        <label class="radio-label" for="avatar-flair-image">
          <RadioButton
            @name="avatar-flair-image"
            @id="avatar-flair-image"
            @value="image"
            @selection={{this.model.flair_type}}
          />
          {{i18n "groups.flair_type.image"}}
        </label>
      </div>

      {{#if this.flairPreviewIcon}}
        <IconPicker
          @name="icon"
          @value={{this.model.flair_icon}}
          @options={{hash maximum=1}}
          @onChange={{fn (mut this.model.flair_icon)}}
        />
      {{else if this.flairPreviewImage}}
        <UppyImageUploader
          @imageUrl={{this.flairImageUrl}}
          @onUploadDone={{this.setFlairImage}}
          @onUploadDeleted={{this.removeFlairImage}}
          @type="group_flair"
          @id="group-flair-uploader"
          class="no-repeat contain-image"
        />
        <div class="control-instructions">
          {{i18n "groups.flair_upload_description"}}
        </div>
      {{/if}}
    </div>

    <div class="control-group">
      <label class="control-label" for="flair_bg_color">{{i18n
          "groups.flair_bg_color"
        }}</label>

      <TextField
        @name="flair_bg_color"
        @value={{this.model.flair_bg_color}}
        @placeholderKey="groups.flair_bg_color_placeholder"
        class="group-flair-bg-color input-xxlarge"
      />
    </div>

    {{#if this.flairPreviewIcon}}
      <div class="control-group">
        <label class="control-label" for="flair_color">{{i18n
            "groups.flair_color"
          }}</label>

        <TextField
          @name="flair_color"
          @value={{this.model.flair_color}}
          @placeholderKey="groups.flair_color_placeholder"
          class="group-flair-color input-xxlarge"
        />
      </div>
    {{/if}}

    <div class="control-group">
      <label class="control-label">{{this.flairPreviewLabel}}</label>

      <div class="avatar-flair-preview">
        <div class="avatar-wrapper">
          <img
            width="45"
            height="45"
            src={{this.demoAvatarUrl}}
            class="avatar actor"
            alt
          />
        </div>

        {{#if
          (or
            this.model.flair_icon
            this.flairImageUrl
            this.model.flairBackgroundHexColor
          )
        }}
          <AvatarFlair
            @flairName={{this.model.name}}
            @flairUrl={{if
              this.flairPreviewIcon
              this.model.flair_icon
              (if this.flairPreviewImage this.flairImageUrl "")
            }}
            @flairBgColor={{this.model.flairBackgroundHexColor}}
            @flairColor={{this.model.flairHexColor}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
