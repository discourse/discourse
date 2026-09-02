import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="username" @title="Username" @type="input" as |field|>
      <field.Control placeholder="Username" />
    </form.Field>
    <form.Field @name="age" @title="Age" @type="input-number" as |field|>
      <field.Control placeholder="Age" @format="small" />
    </form.Field>
    <form.Field @name="website" @title="Website" @type="input" as |field|>
      <field.Control @after=".com" @before="https://" @format="large" />
    </form.Field>
    <form.Field @name="after" @title="After" @type="input" as |field|>
      <field.Control @after=".com" />
    </form.Field>
    <form.Field @name="before" @title="Before" @type="input" as |field|>
      <field.Control @before="https://" />
    </form.Field>
    <form.Field
      @description="An important password"
      @name="secret"
      @title="Secret"
      @type="password"
      as |field|
    >
      <field.Control />
    </form.Field>
  </Form>
</template>
