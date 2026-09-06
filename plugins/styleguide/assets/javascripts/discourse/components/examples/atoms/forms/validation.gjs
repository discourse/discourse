import Form from "discourse/components/form";

export default <template>
  <Form @validateOn="change" as |form|>
    <form.Field
      @title="Username"
      @name="username"
      @validation="required"
      @type="input"
      as |field|
    >
      <field.Control />
    </form.Field>

    <form.Field
      @name="accept_terms"
      @title="Accept terms"
      @validation="required"
      @format="large"
      @type="checkbox"
      as |field|
    >
      <field.Control />
    </form.Field>

    <form.Submit />
  </Form>
</template>
