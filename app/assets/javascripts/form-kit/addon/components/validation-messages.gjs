import Component from "@glimmer/component";
import { getOwner } from "@ember/application";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import Node from "form-kit/lib/node";
import { and } from "truth-helpers";
import { z } from "zod";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { isTesting } from "discourse-common/config/environment";
import icon from "discourse-common/helpers/d-icon";
import DFloatBody from "float-kit/components/d-float-body";
import { MENU } from "float-kit/lib/constants";
import DMenuInstance from "float-kit/lib/d-menu-instance";
import Col from "./col";
import Text from "./inputs/text";
import Row from "./row";

export default class ValidationMessages extends Component {
  <template>
    {{#if @node.allValidationMessages}}
      {{icon "exclamation-triangle"}}
      {{#each @node.allValidationMessages as |message|}}
        {{message}}
      {{/each}}
    {{/if}}
  </template>
}
