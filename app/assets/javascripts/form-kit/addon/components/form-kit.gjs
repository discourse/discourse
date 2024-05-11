import Component from "@glimmer/component";
import { getOwner } from "@ember/application";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import ValidationMessages from "form-kit/components/validation-messages";
import Node from "form-kit/lib/node";
import { and } from "truth-helpers";
import { z } from "zod";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { isTesting } from "discourse-common/config/environment";
import DFloatBody from "float-kit/components/d-float-body";
import { MENU } from "float-kit/lib/constants";
import DMenuInstance from "float-kit/lib/d-menu-instance";
import Col from "./col";
import Text from "./inputs/text";
import Row from "./row";

export default class FormKit extends Component {
  formeElement = null;

  registerFormElement = modifier((element) => {
    this.formElement = element;
  });

  constructor() {
    super(...arguments);
    console.log("init");

    this.node = new Node({ type: "group" });
  }

  @action
  onSubmit(event) {
    console.log(z);
    const formData = new FormData(this.formElement);
    console.log(Object.fromEntries(formData.entries()));
    // this.args.onSubmit(Object.fromEntries(this.formData.entries()));
  }

  <template>
    <form class="d-form" {{this.registerFormElement}}>
      {{yield
        (hash
          Text=(component Text node=this.node)
          Row=Row
          Col=Col
          ValidationMessages=(component ValidationMessages node=this.node)
        )
      }}

      {{#if @onSubmit}}
        <DButton
          class="d-form__submit btn-primary"
          @label="Submit"
          @action={{this.onSubmit}}
        />
      {{/if}}
    </form>
  </template>
}
