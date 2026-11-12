import Form from "discourse/components/form";

export default <template>
  <Form @validateOn="change" as |form|>
    <form.Field
      @name="username"
      @title="Username"
      @type="input"
      @validation="required"
      as |field|
    >
      <field.Control />
    </form.Field>

    <form.Field
      @format="large"
      @name="accept_terms"
      @title="Accept terms"
      @type="checkbox"
      @validation="required"
      as |field|
    >
      <field.Control />
    </form.Field>

    <form.Submit />
  </Form>
</template>
