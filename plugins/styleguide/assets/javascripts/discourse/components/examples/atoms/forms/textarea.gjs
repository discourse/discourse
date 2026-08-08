import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Query" @name="query" @type="textarea" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
