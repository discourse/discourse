import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Image" @name="image" @type="image" as |field|>
      <field.Control @type="avatar" />
    </form.Field>
  </Form>
</template>
