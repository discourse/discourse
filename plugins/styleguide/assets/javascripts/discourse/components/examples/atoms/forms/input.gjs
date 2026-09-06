import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Username" @name="username" @type="input" as |field|>
      <field.Control placeholder="Username" />
    </form.Field>
    <form.Field @title="Age" @name="age" @type="input-number" as |field|>
      <field.Control placeholder="Age" @format="small" />
    </form.Field>
    <form.Field @title="Website" @name="website" @type="input" as |field|>
      <field.Control @before="https://" @after=".com" @format="large" />
    </form.Field>
    <form.Field @title="After" @name="after" @type="input" as |field|>
      <field.Control @after=".com" />
    </form.Field>
    <form.Field @title="Before" @name="before" @type="input" as |field|>
      <field.Control @before="https://" />
    </form.Field>
    <form.Field
      @title="Secret"
      @name="secret"
      @description="An important password"
      @type="password"
      as |field|
    >
      <field.Control />
    </form.Field>
  </Form>
</template>
