import { array } from "@ember/helper";
import Form from "discourse/components/form";

export default <template>
  <Form as |form|>
    <form.Field @name="color" @title="Color" @type="color" as |field|>
      <field.Control
        placeholder="RRGGBB"
        @colors={{array "FF0000" "00FF00" "0000FF" "FFFF00" "FF00FF" "00FFFF"}}
        @usedColors={{array "00FF00"}}
      />
    </form.Field>
  </Form>
</template>
