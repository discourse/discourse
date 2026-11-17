import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="enabled" @title="Enabled" @type="select" as |field|>
      <field.Control as |select|>
        <select.Option @value="true">Yes</select.Option>
        <select.Option @value="false">No</select.Option>
      </field.Control>
    </form.Field>
  </Form>
</template>
