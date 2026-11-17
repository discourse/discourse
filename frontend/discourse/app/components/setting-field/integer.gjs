import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

export function preventDecimal(event) {
  if (event.key === "." || event.key === ",") {
    event.preventDefault();
  }
}

export default <template>
  <@field.Control
    max={{@definition.max}}
    min={{@definition.min}}
    @after={{if
      @definition.unit
      (i18n (concat "admin.site_settings.units." @definition.unit))
    }}
    {{on "keydown" preventDecimal}}
  />
</template>
