import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.CheckboxGroup @title="I give explicit permission" as |checkboxGroup|>
      <checkboxGroup.Field
        @name="contract"
        @title="Use my email for any purpose."
        @type="checkbox"
        as |field|
      >
        <field.Control>Including signing up for services I can't unsubscribe to.</field.Control>
      </checkboxGroup.Field>
      <checkboxGroup.Field
        @name="contract2"
        @title="Sign my soul away."
        @type="checkbox"
        as |field|
      >
        <field.Control>Will severly impact the afterlife experience.</field.Control>
      </checkboxGroup.Field>
    </form.CheckboxGroup>
  </Form>
</template>
