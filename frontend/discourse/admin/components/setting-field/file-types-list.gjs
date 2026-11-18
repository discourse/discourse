import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import CompactListControl from "discourse/components/setting-field/compact-list";
import ListSetting from "discourse/select-kit/components/list-setting";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const TYPE_GROUPS = [
  {
    name: "image",
    label: "admin.site_settings.file_types_list.add_image_types",
    types: ["gif", "png", "jpeg", "jpg", "heic", "heif", "webp", "avif", "svg"],
  },
  {
    name: "video",
    label: "admin.site_settings.file_types_list.add_video_types",
    types: ["mov", "mp4", "webm", "m4v", "3gp", "ogv", "avi", "mpeg"],
  },
  {
    name: "audio",
    label: "admin.site_settings.file_types_list.add_audio_types",
    types: ["mp3", "ogg", "m4a", "wav", "aac", "flac"],
  },
  {
    name: "document",
    label: "admin.site_settings.file_types_list.add_document_types",
    types: ["txt", "pdf", "doc", "docx", "csv"],
  },
];

function listTypes(types) {
  return types.join(", ");
}

export default class SettingFieldFileTypesList extends CompactListControl {
  @service toasts;

  @action
  insertDefaultTypes(types) {
    const currentTypes = this.settingValue;
    const addedTypes = types.filter((type) => !currentTypes.includes(type));

    if (isEmpty(addedTypes)) {
      return;
    }

    this.toasts.success({
      data: {
        message: i18n("admin.site_settings.file_types_list.add_types_toast", {
          types: listTypes(addedTypes),
        }),
      },
    });

    this.onChange([...currentTypes, ...addedTypes]);
  }

  <template>
    <@field.Control>
      <div class="file-types-list">
        <ListSetting
          @choices={{this.choices}}
          @onChange={{this.onChange}}
          @onChangeChoices={{this.onChangeChoices}}
          @options={{hash allowAny=this.allowAny disabled=@field.disabled}}
          @settingName={{@definition.key}}
          @value={{this.settingValue}}
        />

        {{#each TYPE_GROUPS as |group|}}
          <DButton
            class="btn-small btn-default file-types-list__button {{group.name}}"
            @action={{fn this.insertDefaultTypes group.types}}
            @disabled={{@field.disabled}}
            @label={{group.label}}
            @translatedTitle={{i18n
              "admin.site_settings.file_types_list.add_types_title"
              types=(listTypes group.types)
            }}
          />
        {{/each}}
      </div>
    </@field.Control>
  </template>
}
