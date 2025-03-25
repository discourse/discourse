import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FKCollection from "discourse/form-kit/components/fk/collection";
import FKField from "discourse/form-kit/components/fk/field";

export default class FKObject extends Component {
  get objectData() {
    return this.args.data.get(this.name);
  }

  get name() {
    return this.args.name
      ? `${this.args.parentName ? this.args.parentName + "." : ""}${
          this.args.name
        }`
      : this.args.parentName;
  }

  <template>
    <div class="form-kit__object" ...attributes>
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
            remove=@remove
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
        this.objectData
      }}
    </div>
  </template>
}
