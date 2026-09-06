import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Icon" @name="icon" @type="icon" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
