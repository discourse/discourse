import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import ListSetting from "discourse/select-kit/components/list-setting";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const IMAGE_TYPES = [
  "gif",
  "png",
  "jpeg",
  "jpg",
  "heic",
  "heif",
  "webp",
  "avif",
  "svg",
];
const VIDEO_TYPES = ["mov", "mp4", "webm", "m4v", "3gp", "ogv", "avi", "mpeg"];
const AUDIO_TYPES = ["mp3", "ogg", "m4a", "wav", "aac", "flac"];
const DOCUMENT_TYPES = ["txt", "pdf", "doc", "docx", "csv"];
const TOKEN_SEPARATOR = "|";
const IMAGE_TYPES_STRING = IMAGE_TYPES.join(", ");
const VIDEO_TYPES_STRING = VIDEO_TYPES.join(", ");
const AUDIO_TYPES_STRING = AUDIO_TYPES.join(", ");
const DOCUMENT_TYPES_STRING = DOCUMENT_TYPES.join(", ");

export default class SettingFieldFileTypesList extends Component {
  @service toasts;

  /** @type {string[] | null} */
  @tracked createdChoices = null;

  get allowAny() {
    return this.args.definition.allow_any !== false;
  }

  get settingValue() {
    return this.args.field.value
      .toString()
      .split(TOKEN_SEPARATOR)
      .filter(Boolean);
  }

  get settingChoices() {
    return uniqueItemsFromArray([
      ...makeArray(this.settingValue),
      ...makeArray(this.args.definition.choices),
      ...makeArray(this.createdChoices),
    ]);
  }

  @action
  onChangeListSetting(value) {
    this.args.field.set(value.join(TOKEN_SEPARATOR));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = uniqueItemsFromArray([
      ...makeArray(this.createdChoices),
      ...makeArray(choices),
    ]);
  }

  @action
  insertDefaultTypes(category) {
    let types;
    switch (category) {
      case "image":
        types = IMAGE_TYPES;
        break;
      case "video":
        types = VIDEO_TYPES;
        break;
      case "audio":
        types = AUDIO_TYPES;
        break;
      case "document":
        types = DOCUMENT_TYPES;
        break;
    }

    const oldTypes = this.settingValue;
    const newTypes = uniqueItemsFromArray([...oldTypes, ...types]);
    const diffTypes = newTypes.filter((type) => !oldTypes.includes(type));

    if (isEmpty(diffTypes)) {
      return;
    }

    this.toasts.success({
      data: {
        message: i18n("admin.site_settings.file_types_list.add_types_toast", {
          types: diffTypes.join(", "),
        }),
      },
    });

    this.args.field.set(newTypes.join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      <div class="file-types-list">
        <ListSetting
          @choices={{this.settingChoices}}
          @onChange={{this.onChangeListSetting}}
          @onChangeChoices={{this.onChangeChoices}}
          @options={{hash allowAny=this.allowAny disabled=@field.disabled}}
          @settingName={{@definition.key}}
          @value={{this.settingValue}}
        />

        <DButton
          class="btn btn-small btn-default file-types-list__button image"
          @action={{fn this.insertDefaultTypes "image"}}
          @disabled={{@field.disabled}}
          @label="admin.site_settings.file_types_list.add_image_types"
          @translatedTitle={{i18n
            "admin.site_settings.file_types_list.add_types_title"
            types=IMAGE_TYPES_STRING
          }}
        />
        <DButton
          class="btn btn-small btn-default file-types-list__button video"
          @action={{fn this.insertDefaultTypes "video"}}
          @disabled={{@field.disabled}}
          @label="admin.site_settings.file_types_list.add_video_types"
          @translatedTitle={{i18n
            "admin.site_settings.file_types_list.add_types_title"
            types=VIDEO_TYPES_STRING
          }}
        />
        <DButton
          class="btn btn-small btn-default file-types-list__button"
          @action={{fn this.insertDefaultTypes "audio"}}
          @disabled={{@field.disabled}}
          @label="admin.site_settings.file_types_list.add_audio_types"
          @translatedTitle={{i18n
            "admin.site_settings.file_types_list.add_types_title"
            types=AUDIO_TYPES_STRING
          }}
        />
        <DButton
          class="btn btn-small btn-default file-types-list__button document"
          @action={{fn this.insertDefaultTypes "document"}}
          @disabled={{@field.disabled}}
          @label="admin.site_settings.file_types_list.add_document_types"
          @translatedTitle={{i18n
            "admin.site_settings.file_types_list.add_types_title"
            types=DOCUMENT_TYPES_STRING
          }}
        />
      </div>
    </@field.Control>
  </template>
}
