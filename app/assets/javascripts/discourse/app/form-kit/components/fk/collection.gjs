import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action, get } from "@ember/object";
import FKField from "discourse/form-kit/components/fk/field";

export default class FKCollection extends Component {
  @action
  remove(index) {
    this.args.remove(this.args.name, index);
  }

  <template>
    {{#each (get @data @name) key="index" as |data index|}}
      {{yield
        (hash
          Field=(component
            FKField
            errors=@errors
            collectionName=@name
            collectionIndex=index
            addError=@addError
            data=data
            set=@set
            registerField=@registerField
            unregisterField=@unregisterField
            triggerRevalidationFor=@triggerRevalidationFor
          )
          remove=this.remove
        )
        index
      }}
    {{/each}}
  </template>
}
