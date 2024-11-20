import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import { makeArray } from "discourse-common/lib/helpers";
import { i18n } from "discourse-i18n";
import ListSetting from "select-kit/components/list-setting";

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

export default class FileTypesList extends Component {
  @service toasts;

  @tracked createdChoices = null;

  get settingValue() {
    return this.args.value.toString().split(TOKEN_SEPARATOR).filter(Boolean);
  }

  get settingChoices() {
    return [
      ...new Set([
        ...makeArray(this.settingValue),
        ...makeArray(this.args.setting.choices),
        ...makeArray(this.createdChoices),
      ]),
    ];
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(TOKEN_SEPARATOR));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = [
      ...new Set([...makeArray(this.createdChoices), ...makeArray(choices)]),
    ];
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

    const oldTypes = this.args.value.split(TOKEN_SEPARATOR);
    const newTypes = [...new Set([...oldTypes, ...types])];
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

    this.args.changeValueCallback(newTypes.join(TOKEN_SEPARATOR));
  }
  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{@setting.setting}}
      @choices={{this.settingChoices}}
      @onChange={{this.onChangeListSetting}}
      @onChangeChoices={{this.onChangeChoices}}
      @options={{hash allowAny=@allowAny}}
    />

    <DButton
      @action={{fn this.insertDefaultTypes "image"}}
      @label="admin.site_settings.file_types_list.add_image_types"
      @translatedTitle={{i18n
        "admin.site_settings.file_types_list.add_types_title"
        types=IMAGE_TYPES_STRING
      }}
      class="btn file-types-list__button image"
    />
    <DButton
      @action={{fn this.insertDefaultTypes "video"}}
      @label="admin.site_settings.file_types_list.add_video_types"
      @translatedTitle={{i18n
        "admin.site_settings.file_types_list.add_types_title"
        types=VIDEO_TYPES_STRING
      }}
      class="btn file-types-list__button video"
    />
    <DButton
      @action={{fn this.insertDefaultTypes "audio"}}
      @label="admin.site_settings.file_types_list.add_audio_types"
      @translatedTitle={{i18n
        "admin.site_settings.file_types_list.add_types_title audio"
        types=AUDIO_TYPES_STRING
      }}
      class="btn file-types-list__button"
    />
    <DButton
      @action={{fn this.insertDefaultTypes "document"}}
      @label="admin.site_settings.file_types_list.add_document_types"
      @translatedTitle={{i18n
        "admin.site_settings.file_types_list.add_types_title"
        types=DOCUMENT_TYPES_STRING
      }}
      class="btn file-types-list__button document"
    />
  </template>
}
