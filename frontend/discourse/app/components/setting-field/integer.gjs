import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

export function preventDecimal(event) {
  if (event.key === "." || event.key === ",") {
    event.preventDefault();
  }
}

function unitLabel(unit, value) {
  return i18n(`admin.site_settings.units.${unit}`, {
    count: Number(value) || 0,
  });
}

export default <template>
  <@field.Control
    max={{@definition.max}}
    min={{@definition.min}}
    @after={{if @definition.unit (unitLabel @definition.unit @field.value)}}
    {{on "keydown" preventDecimal}}
  />
</template>
