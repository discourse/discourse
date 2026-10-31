import Component from "@glimmer/component";
import Form from "discourse/components/form";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures.js";

export default class FormFieldSelectExample extends Component {
  data = { locale: "es", locales: ["en"] };

  <template>
    <Form class="select-examples__form" @data={{this.data}} as |form|>
      <form.Field
        @name="locale"
        @title={{i18n "styleguide.sections.select.form_field_locale"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <DSelect
            @describedBy={{field.describedBy}}
            @disabled={{field.disabled}}
            @id={{field.id}}
            @identifier="sg-form-locale"
            @invalid={{if field.error true false}}
            @items={{LOCALES}}
            @onChange={{field.set}}
            @value={{field.value}}
          />
        </field.Control>
      </form.Field>
      <form.Field
        @format="large"
        @name="locales"
        @title={{i18n "styleguide.sections.select.form_field_locales"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <DSelect
            @describedBy={{field.describedBy}}
            @disabled={{field.disabled}}
            @id={{field.id}}
            @identifier="sg-form-locales"
            @invalid={{if field.error true false}}
            @items={{LOCALES}}
            @multiple={{true}}
            @onChange={{field.set}}
            @value={{field.value}}
          />
        </field.Control>
      </form.Field>
    </Form>
  </template>
}
