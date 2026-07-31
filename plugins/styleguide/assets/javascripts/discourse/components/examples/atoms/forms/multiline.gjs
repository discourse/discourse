import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Row as |row|>
      <row.Col @size={{6}}>
        <form.Field
          @title="Username"
          @name="username"
          @validation="required"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>
      </row.Col>
      <row.Col @size={{6}}>
        <form.Field @title="Email" @name="email" @type="input" as |field|>
          <field.Control />
        </form.Field>
      </row.Col>

      <row.Col @size={{12}}>
        <form.Field @title="Address" @name="address" @type="input" as |field|>
          <field.Control />
        </form.Field>
      </row.Col>
    </form.Row>
  </Form>
</template>
