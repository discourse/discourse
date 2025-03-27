import Component, { Textarea } from "@ember/component";
import { i18n } from "discourse-i18n";

export default class SiteCustomizationChangeField extends Component {
  <template>
    {{#if this.field}}
      <section class="field">
        <b>{{i18n this.name}}</b>: ({{i18n
          "character_count"
          count=this.field.length
        }})
        <br />
        <Textarea @value={{this.field}} class="plain" />
      </section>
    {{/if}}
  </template>
}
