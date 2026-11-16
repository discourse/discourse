import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import ListSetting from "discourse/select-kit/components/list-setting";
import { i18n } from "discourse-i18n";

// Assigned by the server based on query ownership, never chosen by users
const RESERVED_QUERY_TAGS = ["default", "custom"];

function isAllowedTag(tag, automaticTags = []) {
  const name = tag?.trim().toLowerCase();
  return !RESERVED_QUERY_TAGS.includes(name) || automaticTags.includes(name);
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
  get choices() {
    const tags = [
      ...(this.args.availableTags ?? []),
      ...(this.args.value ?? []),
    ];
    return this.#uniqueTags(
      tags.filter((tag) => isAllowedTag(tag, this.args.automaticTags))
    );
  }

  get mandatoryValues() {
    return this.args.automaticTags?.length
      ? this.args.automaticTags.join("|")
      : null;
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
  </template>
}
