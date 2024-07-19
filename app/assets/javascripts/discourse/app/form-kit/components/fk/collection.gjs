import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FKField from "discourse/form-kit/components/fk/field";

export default class FKCollection extends Component {
  @action
  remove(index) {
    this.args.remove(this.args.name, index);
  }

  get collectionValue() {
    return this.args.data.get(this.args.name);
  }

  <template>
    <div class="form-kit__collection">
      {{#each this.collectionValue key="index" as |data index|}}
        {{yield
          (hash
            Field=(component
              FKField
              errors=@errors
              collectionName=@name
              collectionIndex=index
              addError=@addError
              data=@data
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
    </div>
  </template>
}
