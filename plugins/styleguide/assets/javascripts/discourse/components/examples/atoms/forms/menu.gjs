import Form from "discourse/components/form";

export default <template>
  <Form as |form data|>
    <form.Field @title="Enabled" @name="enabled" @type="menu" as |field|>
      <field.Control @selection={{data.enabled}} as |menu|>
        <menu.Item @value="true">Yes</menu.Item>
        <menu.Divider />
        <menu.Item @value="false">No</menu.Item>
      </field.Control>
    </form.Field>
  </Form>
</template>
