import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Color" @name="color" @type="color" as |field|>
      <field.Control @allowNamedColors={{true}} placeholder="red, FF0000" />
    </form.Field>
  </Form>
</template>
