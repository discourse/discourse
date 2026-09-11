import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="query" @title="Query" @type="composer" as |field|>
      <field.Control />
    </form.Field>
  </Form>
</template>
