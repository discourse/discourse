import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ListSetting from "discourse/select-kit/components/list-setting";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

// Assigned by the server based on query ownership, never chosen by users
const RESERVED_QUERY_TAGS = ["default", "custom"];

function isAllowedTag(tag, automaticTags = []) {
  const name = tag?.trim().toLowerCase();
  return !RESERVED_QUERY_TAGS.includes(name) || automaticTags.includes(name);
}

/** A tag as the picker's record. */
function tagRecord(tag) {
  const name = tag.trim();
  return { id: name, name };
}

class QueryTagListSetting extends ListSetting {
  validateCreate(filter, content) {
    return (
      isAllowedTag(filter, this.automaticTags) &&
      super.validateCreate(filter, content)
    );
  }
}

export default class QueryTagChooser extends Component {
  @service siteSettings;

  get choices() {
    const tags = [
      ...(this.args.availableTags ?? []),
      ...(this.args.value ?? []),
    ];
    return this.#uniqueTags(
      tags.filter((tag) => isAllowedTag(tag, this.args.automaticTags))
    );
  }

  get lockedTags() {
    return this.args.automaticTags ?? [];
  }

  get mandatoryValues() {
    return this.args.automaticTags?.length
      ? this.args.automaticTags.join("|")
      : null;
  }

  /** The choices with a held tag's own spelling, so its option matches what is held. */
  get options() {
    const tags = [
      ...(this.args.value ?? []),
      ...(this.args.availableTags ?? []),
    ];
    return this.#uniqueTags(
      tags.filter((tag) => isAllowedTag(tag, this.args.automaticTags))
    ).map(tagRecord);
  }

  /** A reserved tag can't be typed in unless the query holds it automatically. */
  @action
  canCreate(tag) {
    return !tag.includes("|") && isAllowedTag(tag, this.args.automaticTags);
  }

  #uniqueTags(tags = []) {
    const tagsByName = new Map();

    for (const tag of tags) {
      const name = tag?.trim();
      if (name && !tagsByName.has(name.toLowerCase())) {
        tagsByName.set(name.toLowerCase(), name);
      }
    }

    return [...tagsByName.values()].sort((left, right) =>
      left.localeCompare(right, undefined, { sensitivity: "base" })
    );
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelect
        class="query-tag-chooser"
        ...attributes
        @allowCreate={{this.canCreate}}
        @ariaLabelledBy={{@ariaLabelledBy}}
        @createOption={{tagRecord}}
        @lockedValues={{this.lockedTags}}
        @multiple={{true}}
        @onChange={{@onChange}}
        @options={{this.options}}
        @texts={{hash lockedHint=(i18n "explorer.automatic_tag_mandatory")}}
        @value={{@value}}
      />
    {{else}}
      <QueryTagListSetting
        class="query-tag-chooser"
        ...attributes
        @automaticTags={{@automaticTags}}
        @choices={{this.choices}}
        @mandatoryValues={{this.mandatoryValues}}
        @mandatoryValueTitle={{i18n "explorer.automatic_tag_mandatory"}}
        @onChange={{@onChange}}
        @options={{hash allowAny=true}}
        @value={{@value}}
      />
    {{/if}}
  </template>
}
