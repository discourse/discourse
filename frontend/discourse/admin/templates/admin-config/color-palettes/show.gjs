import { array } from "@ember/helper";
import ColorPalette from "discourse/admin/components/admin-config-areas/color-palette";

export default <template>
  {{#each (array @model) as |colorPalette|}}
    <ColorPalette @colorPalette={{colorPalette}} />
  {{/each}}
</template>
