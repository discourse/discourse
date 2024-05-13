import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import ValidationMessages from "form-kit/components/validation-messages";
import Node from "form-kit/lib/node";
import DButton from "discourse/components/d-button";
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
    <form class="d-form" {{this.registerFormElement}}>
      {{yield
        (hash
          Text=(component Text node=this.node)
          Section=(component Section node=this.node)
          Row=(component Row node=this.node)
          Col=(component Col node=this.node)
          Section=(component Section node=this.node)
          ValidationMessages=(component ValidationMessages node=this.node)
        )
      }}

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
