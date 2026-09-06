import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.InputGroup as |inputGroup|>
      <inputGroup.Field
        @title="Username"
        @name="username"
        @type="input"
        as |field|
      >
        <field.Control />
      </inputGroup.Field>
      <inputGroup.Field @title="Email" @name="email" @type="input" as |field|>
        <field.Control />
      </inputGroup.Field>
    </form.InputGroup>
  </Form>
</template>
