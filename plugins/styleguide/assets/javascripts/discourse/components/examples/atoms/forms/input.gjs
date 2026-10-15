import { fn, hash } from "@ember/helper";
import Form from "discourse/components/form";
import DNativeSelect from "discourse/ui-kit/d-native-select";

export default <template>
  <Form @data={{hash length=100 unit="px"}} as |form data|>
    <form.Field @name="username" @title="Username" @type="input" as |field|>
      <field.Control placeholder="Username" />
    </form.Field>
    <form.Field @name="age" @title="Age" @type="input-number" as |field|>
      <field.Control placeholder="Age" @format="small" />
    </form.Field>
    <form.Field @name="website" @title="Website" @type="input" as |field|>
      <field.Control @after=".com" @before="https://" @format="large" />
    </form.Field>
    <form.Field @name="after" @title="After" @type="input" as |field|>
      <field.Control @after=".com" />
    </form.Field>
    <form.Field @name="before" @title="Before" @type="input" as |field|>
      <field.Control @before="https://" />
    </form.Field>
    <form.Field
      @name="percentage"
      @title="Percentage"
      @type="input-number"
      as |field|
    >
      <field.Control @after="%" />
    </form.Field>
    <form.Field @name="length" @title="Length" @type="input-number" as |field|>
      <field.Control>
        <:after>
          <DNativeSelect
            aria-label="Length unit"
            disabled={{field.disabled}}
            @includeNone={{false}}
            @onChange={{fn form.set "unit"}}
            @value={{data.unit}}
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
      @description="An important password"
      @name="secret"
      @title="Secret"
      @type="password"
      as |field|
    >
      <field.Control />
    </form.Field>
  </Form>
</template>
