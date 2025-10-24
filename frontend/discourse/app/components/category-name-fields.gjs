/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import TextField from "discourse/components/text-field";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class CategoryNameFields extends Component {
  <template>
    <PluginOutlet
      @name="category-name-fields-details"
      @outletArgs={{lazyHash category=this.category}}
    >
      <section class="field category-name-fields">
        {{#unless this.category.isUncategorizedCategory}}
          <section class="field-item">
            <label>{{i18n "category.name"}}</label>
            <TextField
              @value={{this.category.name}}
              @placeholderKey="category.name_placeholder"
              @maxlength="50"
              class="category-name"
            />
          </section>
        {{/unless}}
        <section class="field-item">
          <label>{{i18n "category.slug"}}</label>
          <TextField
            @value={{this.category.slug}}
            @placeholderKey="category.slug_placeholder"
            @maxlength="255"
          />
        </section>
      </section>
    </PluginOutlet>
  </template>
}
