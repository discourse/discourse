import { on } from "@ember/modifier";

export function preventDecimal(event) {
  if (event.key === "." || event.key === ",") {
    event.preventDefault();
  }
}

export default <template>
  <@field.Control
    max={{@definition.max}}
    min={{@definition.min}}
    {{on "keydown" preventDecimal}}
  />
</template>
