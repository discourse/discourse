import { on } from "@ember/modifier";

export function preventDecimal(event) {
  if (event.key === "." || event.key === ",") {
    event.preventDefault();
  }
}

export default <template>
  <@field.Control
    min={{@definition.min}}
    max={{@definition.max}}
    {{on "keydown" preventDecimal}}
  />
</template>
