import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { notEq } from "truth-helpers";
import bodyClass from "discourse/helpers/body-class";
import deprecated from "discourse/lib/deprecated";

// Can add a body class from within a component
export default class DSection extends Component {
  constructor() {
    super(...arguments);
    deprecated(
      `<DSection> is deprecated. Use {{body-class "foo-page" "bar"}} and/or <section></section> instead.`,
      {
        since: "3.2.0.beta1",
        dropFrom: "3.3.0.beta1",
        id: "discourse.d-section",
      }
    );
  }

  <template>
    {{#if @pageClass}}
      {{bodyClass (concat @pageClass "-page")}}
    {{/if}}

    {{#if @bodyClass}}
      {{bodyClass @bodyClass}}
    {{/if}}

    {{#if (notEq @tagName "")}}
      <section id={{@id}} class={{@class}} ...attributes>{{yield}}</section>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
