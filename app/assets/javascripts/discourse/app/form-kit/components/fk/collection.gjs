import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import FKField from "discourse/form-kit/components/fk/field";
import FKObject from "discourse/form-kit/components/fk/object";
import element from "discourse/helpers/element";

export default class FKCollection extends Component {
  @action
  remove(index) {
    this.args.remove(this.name, index);
  }

  @action
  componentFor(componentClass, index) {
    const instance = this;
    const baseArguments = {
      collectionIndex: index,
      addError: instance.args.addError,
      set: instance.args.set,
      triggerRevalidationFor: instance.args.triggerRevalidationFor,
      parentName: `${instance.name}.${index}`,
      registerField: instance.args.registerField,
      unregisterField: instance.args.unregisterField,
      get errors() {
        return instance.args.errors;
      },
      get data() {
        return instance.args.data;
      },
    };

    if (componentClass === FKCollection || componentClass === FKObject) {
      baseArguments.remove = instance.args.remove;
    }

    return curryComponent(componentClass, baseArguments, getOwner(this));
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
              Field=(this.componentFor FKField index)
              Object=(this.componentFor FKObject index)
              Collection=(this.componentFor FKCollection index)
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
