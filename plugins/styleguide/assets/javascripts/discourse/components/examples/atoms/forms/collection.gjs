import { array, fn, hash } from "@ember/helper";
import Form from "discourse/components/form";

export default <template>
  <Form
    @data={{hash foo=(array (hash bar=1 baz=2) (hash bar=3 baz=4))}}
    as |form|
  >
    <form.Button @action={{fn form.addItemToCollection "foo"}} @icon="plus" />

    <form.Collection @name="foo" as |collection index|>
      <form.Row as |row|>
        <row.Col @size={{6}}>
          <collection.Field @title="Bar" @name="bar" @type="input" as |field|>
            <field.Control />
          </collection.Field>
        </row.Col>

        <row.Col @size={{4}}>
          <collection.Field @title="Baz" @name="baz" @type="input" as |field|>
            <field.Control />
          </collection.Field>
        </row.Col>

        <row.Col @size={{2}}>
          <form.Button @action={{fn collection.remove index}} @icon="minus" />
        </row.Col>
      </form.Row>
    </form.Collection>
  </Form>
</template>
