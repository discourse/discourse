import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Color" @name="color" @type="color" as |field|>
      <field.Control placeholder="RRGGBB" />
    </form.Field>
  </Form>
</template>
