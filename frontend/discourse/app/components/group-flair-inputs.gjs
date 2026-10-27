import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action, get } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import getURL from "discourse/lib/get-url";
import { convertIconClass } from "discourse/lib/icon-library";
import { ensureSpriteSymbol } from "discourse/lib/svg-sprite-loader";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class GroupFlairInputs extends Component {
  demoAvatarUrl = getURL("/images/avatar.png");

  constructor() {
    super(...arguments);

    const icon = convertIconClass(this.args.model.flair_icon || "");
    if (icon) {
      ensureSpriteSymbol(icon);
    }
  }

  get flairPreviewIcon() {
    return get(this.args.model, "flair_type") === "icon";
  }

  get flairPreviewImage() {
    return get(this.args.model, "flair_type") === "image";
  }

  get flairImageUrl() {
    const url = get(this.args.model, "flair_url");
    return url?.includes("/") ? url : null;
  }

  get flairPreviewLabel() {
    const key = this.flairPreviewImage ? "image" : "icon";
    return i18n(`groups.flair_preview_${key}`);
  }

  @action
  setFlairImage(upload) {
    this.args.model.setProperties({
      flair_url: getURL(upload.url),
      flair_upload_id: upload.id,
    });
  }

  @action
  removeFlairImage() {
    this.args.model.setProperties({
      flair_url: null,
      flair_upload_id: null,
    });
  }

  <template>
    <div class="group-flair-inputs" ...attributes>
      <div class="control-group">
        <label class="control-label" for="flair_url">{{i18n
            "groups.flair_url"
          }}</label>

        <div class="radios">
          <label class="radio-label" for="avatar-flair-icon">
            <DRadioButton
              @id="avatar-flair-icon"
              @name="avatar-flair-icon"
              @selection={{@model.flair_type}}
              @value="icon"
            />
            {{i18n "groups.flair_type.icon"}}
          </label>

          <label class="radio-label" for="avatar-flair-image">
            <DRadioButton
              @id="avatar-flair-image"
              @name="avatar-flair-image"
              @selection={{@model.flair_type}}
              @value="image"
            />
            {{i18n "groups.flair_type.image"}}
          </label>
        </div>

        {{#if this.flairPreviewIcon}}
          <DIconGridPicker
            @label={{unless @model.flair_icon (i18n "select_placeholder")}}
            @onChange={{fn (mut @model.flair_icon)}}
            @onlyAvailable={{false}}
            @showCaret={{true}}
            @value={{@model.flair_icon}}
          />
        {{else if this.flairPreviewImage}}
          <UppyImageUploader
            class="no-repeat contain-image"
            @id="group-flair-uploader"
            @imageUrl={{this.flairImageUrl}}
            @onUploadDeleted={{this.removeFlairImage}}
            @onUploadDone={{this.setFlairImage}}
            @type="group_flair"
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

        <DTextField
          class="group-flair-bg-color input-xxlarge"
          @name="flair_bg_color"
          @placeholderKey="groups.flair_bg_color_placeholder"
          @value={{@model.flair_bg_color}}
        />
      </div>

      {{#if this.flairPreviewIcon}}
        <div class="control-group">
          <label class="control-label" for="flair_color">{{i18n
              "groups.flair_color"
            }}</label>

          <DTextField
            class="group-flair-color input-xxlarge"
            @name="flair_color"
            @placeholderKey="groups.flair_color_placeholder"
            @value={{@model.flair_color}}
          />
        </div>
      {{/if}}

      <div class="control-group">
        <label class="control-label">{{this.flairPreviewLabel}}</label>

        <div class="avatar-flair-preview">
          <div class="avatar-wrapper">
            <img
              alt
              class="avatar actor"
              height="45"
              src={{this.demoAvatarUrl}}
              width="45"
            />
          </div>

          {{#if
            (or
              @model.flair_icon
              this.flairImageUrl
              @model.flairBackgroundHexColor
            )
          }}
            <DAvatarFlair
              @flairBgColor={{@model.flairBackgroundHexColor}}
              @flairColor={{@model.flairHexColor}}
              @flairName={{@model.name}}
              @flairUrl={{if
                this.flairPreviewIcon
                @model.flair_icon
                (if this.flairPreviewImage this.flairImageUrl "")
              }}
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
