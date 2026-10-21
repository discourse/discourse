import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.InputGroup as |inputGroup|>
      <inputGroup.Field
        @name="username"
        @title="Username"
        @type="input"
        as |field|
      >
        <field.Control />
      </inputGroup.Field>
      <inputGroup.Field @name="email" @title="Email" @type="input" as |field|>
        <field.Control />
      </inputGroup.Field>
    </form.InputGroup>
  </Form>
</template>
