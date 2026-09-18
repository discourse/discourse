import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import ListSetting from "discourse/select-kit/components/list-setting";

const DEFAULT_QUERY_TAG = "default";

class QueryTagListSetting extends ListSetting {
  validateCreate(filter, content) {
    return (
      (this.allowDefaultTag ||
        filter.trim().toLowerCase() !== DEFAULT_QUERY_TAG) &&
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
      this.args.allowDefaultTag
        ? tags
        : tags.filter((tag) => tag?.trim().toLowerCase() !== DEFAULT_QUERY_TAG)
    );
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
      @allowDefaultTag={{@allowDefaultTag}}
      @choices={{this.choices}}
      @mandatoryValues={{@mandatoryValues}}
      @mandatoryValueTitle={{@mandatoryValueTitle}}
      @onChange={{@onChange}}
      @options={{hash allowAny=true}}
      @value={{@value}}
    />
  </template>
}
