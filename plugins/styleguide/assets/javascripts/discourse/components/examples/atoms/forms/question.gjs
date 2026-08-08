import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Enabled" @name="enabled" @type="question" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
