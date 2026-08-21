import {
  formatExactPageviewCount,
  formatPageviewCount,
} from "discourse/admin/lib/format-pageview-count";
import DTooltip from "discourse/float-kit/components/d-tooltip";

export default <template>
  <DTooltip @content={{formatExactPageviewCount @value}} ...attributes>
    <:trigger>{{yield (formatPageviewCount @value)}}</:trigger>
  </DTooltip>
</template>
