import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import FKField from "discourse/form-kit/components/fk/field";
import FKObject from "discourse/form-kit/components/fk/object";
import element from "discourse/helpers/element";

export default class FKCollection extends Component {
  @action
  remove(index) {
    this.args.remove(this.name, index);
  }

  get collectionData() {
    return this.args.data.get(this.name).map((item, index) => {
      return {
        identifier: `${this.name}-${index}`,
        item,
      };
    });
  }

  get name() {
    return this.args.name
      ? `${this.args.parentName ? this.args.parentName + "." : ""}${
          this.args.name
        }`
      : this.args.parentName;
  }

  get tagName() {
    return this.args.tagName || "div";
  }

  <template>
    {{#let (element this.tagName) as |Wrapper|}}
      <Wrapper class="form-kit__collection">
        {{#each this.collectionData key="identifier" as |data index|}}
          {{yield
            (hash
              Field=(component
                FKField
                errors=@errors
                collectionIndex=index
                addError=@addError
                data=@data
                set=@set
                registerField=@registerField
                unregisterField=@unregisterField
                triggerRevalidationFor=@triggerRevalidationFor
                parentName=(concat this.name "." index)
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
                parentName=(concat this.name "." index)
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
                parentName=(concat this.name "." index)
                remove=@remove
              )
              remove=this.remove
            )
            index
            data.item
          }}
        {{/each}}
      </Wrapper>
    {{/let}}
  </template>
}
