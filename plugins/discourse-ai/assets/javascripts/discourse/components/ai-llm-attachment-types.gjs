import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import ListSetting from "discourse/select-kit/components/list-setting";
import { i18n } from "discourse-i18n";

const DEFAULT_CHOICES = [
  "pdf",
  "txt",
  "doc",
  "docx",
  "rtf",
  "html",
  "markdown",
];

/**
 * @component ai-llm-attachment-types
 * @param {string[]} [this.args.value]
 * @param {Function} [this.args.onChange]
 */
export default class AiLlmAttachmentTypes extends Component {
  @tracked currentValue = this.args.value || [];

  get settingChoices() {
    return uniqueItemsFromArray([
      ...DEFAULT_CHOICES,
      ...this.currentValue,
    ]).sort();
  }

  @action
  handleChange(newValues) {
    const normalized = (newValues || [])
      .map((v) => v.toString().toLowerCase().trim())
      .filter(Boolean);
    this.currentValue = uniqueItemsFromArray(normalized);
    this.args.onChange?.(this.currentValue);
  }

  <template>
    <ListSetting
      @value={{this.currentValue}}
      @settingName="allowed_attachment_types"
      @choices={{this.settingChoices}}
      @onChange={{this.handleChange}}
      @allowAny={{true}}
      @options={{hash
        noneLabel=(i18n "discourse_ai.llms.attachment_types_placeholder")
      }}
    />
  </template>
}
