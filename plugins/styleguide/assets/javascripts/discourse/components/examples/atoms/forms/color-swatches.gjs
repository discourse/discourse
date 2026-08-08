import { array } from "@ember/helper";
import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @title="Color" @name="color" @type="color" as |field|>
      <field.Control
        @colors={{array "FF0000" "00FF00" "0000FF" "FFFF00" "FF00FF" "00FFFF"}}
        @usedColors={{array "00FF00"}}
        placeholder="RRGGBB"
      />
    </form.Field>
  </Form>
</template>
