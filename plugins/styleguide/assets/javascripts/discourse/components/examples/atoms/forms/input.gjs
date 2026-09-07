import { fn, hash } from "@ember/helper";
import Form from "discourse/components/form";
import DNativeSelect from "discourse/ui-kit/d-native-select";

export default <template>
  <Form @data={{hash length=100 unit="px"}} as |form data|>
    <form.Field @title="Username" @name="username" @type="input" as |field|>
      <field.Control placeholder="Username" />
    </form.Field>
    <form.Field @title="Age" @name="age" @type="input-number" as |field|>
      <field.Control placeholder="Age" @format="small" />
    </form.Field>
    <form.Field @title="Website" @name="website" @type="input" as |field|>
      <field.Control @before="https://" @after=".com" @format="large" />
    </form.Field>
    <form.Field @title="After" @name="after" @type="input" as |field|>
      <field.Control @after=".com" />
    </form.Field>
    <form.Field @title="Before" @name="before" @type="input" as |field|>
      <field.Control @before="https://" />
    </form.Field>
    <form.Field
      @title="Percentage"
      @name="percentage"
      @type="input-number"
      as |field|
    >
      <field.Control @after="%" />
    </form.Field>
    <form.Field @title="Length" @name="length" @type="input-number" as |field|>
      <field.Control>
        <:after>
          <DNativeSelect
            aria-label="Length unit"
            disabled={{field.disabled}}
            @includeNone={{false}}
            @value={{data.unit}}
            @onChange={{fn form.set "unit"}}
            as |select|
          >
            <select.Option @value="px">px</select.Option>
            <select.Option @value="%">%</select.Option>
            <select.Option @value="rem">rem</select.Option>
          </DNativeSelect>
        </:after>
      </field.Control>
    </form.Field>
    <form.Field
      @title="Secret"
      @name="secret"
      @description="An important password"
      @type="password"
      as |field|
    >
      <field.Control />
    </form.Field>
  </Form>
</template>
