import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field
      @format="full"
      @name="enabled"
      @title="Enabled"
      @type="radio-group"
      as |field|
    >
      <field.Control as |radioGroup|>
        <radioGroup.Radio @value="true">Yes</radioGroup.Radio>
        <radioGroup.Radio @value="false" as |radio|>
          <radio.Title>No</radio.Title>
          <radio.Description>
            Choosing no, will make you ineligible for the contest.
          </radio.Description>
        </radioGroup.Radio>
      </field.Control>
    </form.Field>
  </Form>
</template>
