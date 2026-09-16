import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="tags" @title="Tags" @type="tag-chooser" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
