import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="color" @title="Color" @type="color" as |field|>
      <field.Control placeholder="RRGGBB" @prefixHex={{true}} />
    </form.Field>
  </Form>
</template>
