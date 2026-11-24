import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import SelectStringList from "discourse/components/setting-field/-internals/select-string-list";
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

/** The categories whose default types a button adds, in button order. */
const DEFAULT_TYPES = [
  { category: "image", label: "add_image_types", types: IMAGE_TYPES },
  { category: "video", label: "add_video_types", types: VIDEO_TYPES },
  { category: "audio", label: "add_audio_types", types: AUDIO_TYPES },
  { category: "document", label: "add_document_types", types: DOCUMENT_TYPES },
];

/** The buttons that add a category's default types to the list. */
const AddTypesButtons = <template>
  {{#each @buttons as |button|}}
    <DButton
      class={{concat @buttonClass " file-types-list__button " button.category}}
      @action={{fn @onInsert button.category}}
      @disabled={{button.disabled}}
      @label={{concat "admin.site_settings.file_types_list." button.label}}
      @translatedTitle={{button.title}}
    />
  {{/each}}
</template>;

export default class FileTypesList extends Component {
  @service siteSettings;
  @service toasts;

  /** @type {string[] | null} */
  @tracked createdChoices = null;

  /** The id of the label that names the add-types buttons in the picker's footer. */
  addTypesLabelId = `${guidFor(this)}-add-types`;

  get settingValue() {
    return this.args.value.toString().split(TOKEN_SEPARATOR).filter(Boolean);
  }

  /**
   * One entry per add-types button: the types it would add, and whether it can add any. A button
   * whose types are all allowed already is disabled, and its title says so.
   */
  get addTypesButtons() {
    const held = this.settingValue;
    return DEFAULT_TYPES.map(({ category, label, types }) => {
      const missing = types.filter((type) => !held.includes(type));
      const title = missing.length
        ? i18n("admin.site_settings.file_types_list.add_types_title", {
            types: missing.join(", "),
          })
        : i18n("admin.site_settings.file_types_list.already_allowed", {
            types: types.join(", "),
          });
      return {
        category,
        label,
        missing,
        title,
        disabled: Boolean(this.args.disabled) || missing.length === 0,
      };
    });
  }

  get settingChoices() {
    return uniqueItemsFromArray([
      ...makeArray(this.settingValue),
      ...makeArray(this.args.setting.choices),
      ...makeArray(this.createdChoices),
    ]);
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(TOKEN_SEPARATOR));
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
    const diffTypes = this.addTypesButtons.find(
      (button) => button.category === category
    ).missing;

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

    this.args.changeValueCallback(
      [...this.settingValue, ...diffTypes].join(TOKEN_SEPARATOR)
    );
  }

  <template>
    <div class="file-types-list">
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <SelectStringList
          @allowAny={{@allowAny}}
          @ariaLabel={{@label}}
          @choices={{makeArray @setting.choices}}
          @disabled={{@disabled}}
          @onChange={{this.onChangeListSetting}}
          @values={{this.settingValue}}
        >
          <:footer>
            <div class="file-types-list__footer">
              <span class="file-types-list__label" id={{this.addTypesLabelId}}>
                {{i18n "admin.site_settings.file_types_list.add_common_types"}}
              </span>
              <div
                aria-labelledby={{this.addTypesLabelId}}
                class="file-types-list__buttons"
                role="group"
              >
                <AddTypesButtons
                  @buttonClass="btn-default btn-small"
                  @buttons={{this.addTypesButtons}}
                  @onInsert={{this.insertDefaultTypes}}
                />
              </div>
            </div>
          </:footer>
        </SelectStringList>
      {{else}}
        <ListSetting
          @choices={{this.settingChoices}}
          @onChange={{this.onChangeListSetting}}
          @onChangeChoices={{this.onChangeChoices}}
          @options={{hash allowAny=@allowAny disabled=@disabled}}
          @settingName={{@setting.setting}}
          @value={{this.settingValue}}
        />

        <AddTypesButtons
          @buttonClass="btn btn-small btn-default"
          @buttons={{this.addTypesButtons}}
          @onInsert={{this.insertDefaultTypes}}
        />
      {{/if}}
    </div>
  </template>
}
