import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import ListSetting from "discourse/select-kit/components/list-setting";

export default class QueryTagChooser extends Component {
  get choices() {
    return this.#uniqueTags([
      ...(this.args.availableTags ?? []),
      ...(this.args.value ?? []),
    ]);
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
    <ListSetting
      class="query-tag-chooser"
      ...attributes
      @choices={{this.choices}}
      @mandatoryValues={{@mandatoryValues}}
      @mandatoryValueTitle={{@mandatoryValueTitle}}
      @onChange={{@onChange}}
      @options={{hash allowAny=true}}
      @value={{@value}}
    />
  </template>
}
