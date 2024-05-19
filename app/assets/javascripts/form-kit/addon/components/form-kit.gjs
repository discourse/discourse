import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import FieldWrapper from "form-kit/components/field-wrapper";
import ValidationMessages from "form-kit/components/validation-messages";
import Node from "form-kit/lib/node";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import Col from "./col";
import Text from "./inputs/text";
import Row from "./row";
import Section from "./section";

export default class FormKit extends Component {
  formeElement = null;

  registerFormElement = modifier((element) => {
    this.formElement = element;
  });

  constructor() {
    super(...arguments);

    console.log("form kit", this.args.horizontal);

    this.node = new Node(
      { type: "group" },
      { horizontal: this.args.horizontal }
    );
  }

  @action
  onSubmit(event) {
    const formData = new FormData(this.formElement);
    console.log(Object.fromEntries(formData.entries()));
    // this.args.onSubmit(Object.fromEntries(this.formData.entries()));
  }

  <template>
    <form class={{concatClass "d-form"}} {{this.registerFormElement}}>
      <Section @node={{this.node}}>
        {{yield
          (hash
            Text=(component FieldWrapper component=Text node=this.node)
            Section=(component Section node=this.node)
            Row=(component Row node=this.node)
            Col=(component Col node=this.node)
            Section=(component Section node=this.node)
            ValidationMessages=(component ValidationMessages node=this.node)
          )
        }}
      </Section>

      {{!-- {{#if @onSubmit}}
        <DButton
          class="d-form__submit btn-primary"
          @label="Submit"
          @action={{this.onSubmit}}
        />
      {{/if}} --}}
    </form>
  </template>
}
