import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Tags" @name="tags" @type="tag-chooser" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
