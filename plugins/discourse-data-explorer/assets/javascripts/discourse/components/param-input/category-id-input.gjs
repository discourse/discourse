import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import CategoryChooser from "select-kit/components/category-chooser";

export default class CategoryIdInput extends Component {
  // CategoryChooser will try to modify the value of value,
  // triggering a setting-on-hash error. So we have to do the dirty work.
  get data() {
    return {
      value: this.args.field.value,
    };
  }

  <template>
    <@field.Custom id={{@field.id}}>
      <CategoryChooser
        @value={{this.data.value}}
        @onChange={{@field.set}}
        @options={{hash
          allowUncategorized=null
          autoInsertNoneItem=true
          none=true
        }}
        name={{@info.identifier}}
      />
    </@field.Custom>
  </template>
}
