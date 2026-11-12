import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="enabled" @title="Enabled" @type="question" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
