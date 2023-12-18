import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";

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

export default class FileTypesList extends Component {
  tokenSeparator = "|";
  createdChoices = null;

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }

  @computed("settingValue", "setting.choices.[]", "createdChoices.[]")
  get settingChoices() {
    return [
      ...new Set([
        ...makeArray(this.settingValue),
        ...makeArray(this.setting.choices),
        ...makeArray(this.createdChoices),
      ]),
    ];
  }

  @action
  onChangeListSetting(value) {
    this.set("value", value.join(this.tokenSeparator));
  }

  @action
  onChangeChoices(choices) {
    this.set("createdChoices", [
      ...new Set([...makeArray(this.createdChoices), ...makeArray(choices)]),
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
    this.set(
      "value",
      [...new Set([...this.value.split(this.tokenSeparator), ...types])].join(
        this.tokenSeparator
      )
    );
  }
}
