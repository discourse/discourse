import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="icon" @title="Icon" @type="icon" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
