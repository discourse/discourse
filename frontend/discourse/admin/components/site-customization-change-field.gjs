/* eslint-disable ember/no-classic-components */
import Component, { Textarea } from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
export default class SiteCustomizationChangeField extends Component {
  <template>
    <div ...attributes>
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
    </div>
  </template>
}
