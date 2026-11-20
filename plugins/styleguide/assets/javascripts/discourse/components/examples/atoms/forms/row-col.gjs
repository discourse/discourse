import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Row as |row|>
      <row.Col @size={{6}}>
        <form.Field
          @name="username"
          @title="Username"
          @type="input"
          @validation="required"
          as |field|
        >
          <field.Control />
        </form.Field>
      </row.Col>
      <row.Col @size={{4}}>
        <form.Field @name="email" @title="Email" @type="input" as |field|>
          <field.Control />
        </form.Field>
      </row.Col>
      <row.Col @size={{2}}>
        <form.Submit />
      </row.Col>
    </form.Row>
  </Form>
</template>
