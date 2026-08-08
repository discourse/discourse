import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Enabled" @name="enabled" @type="toggle" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
