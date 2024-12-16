import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FKCollection from "discourse/form-kit/components/fk/collection";
import FKField from "discourse/form-kit/components/fk/field";

export default class FKObject extends Component {
  get objectData() {
    return this.args.data.get(this.name);
  }

  get name() {
    return this.args.parentName
      ? `${this.args.parentName}.${this.args.name}`
      : this.args.name;
  }

  get keys() {
    return Object.keys(this.objectData);
  }

  entryData(name) {
    return this.objectData[name];
  }

  <template>
    <div class="form-kit__object">
      {{#each this.keys key="index" as |name|}}
        {{yield
          (hash
            Field=(component
              FKField
              errors=@errors
              addError=@addError
              data=@data
              set=@set
              registerField=@registerField
              unregisterField=@unregisterField
              triggerRevalidationFor=@triggerRevalidationFor
              parentName=this.name
            )
            Object=(component
              FKObject
              errors=@errors
              addError=@addError
              data=@data
              set=@set
              registerField=@registerField
              unregisterField=@unregisterField
              triggerRevalidationFor=@triggerRevalidationFor
              parentName=this.name
            )
            Collection=(component
              FKCollection
              errors=@errors
              addError=@addError
              data=@data
              set=@set
              registerField=@registerField
              unregisterField=@unregisterField
              triggerRevalidationFor=@triggerRevalidationFor
              parentName=this.name
              remove=@remove
            )
          )
          name
          (this.entryData name)
        }}
      {{/each}}
    </div>
  </template>
}
