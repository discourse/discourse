import {
  formatExactPageviewCount,
  formatPageviewCount,
  isPageviewCountRounded,
} from "discourse/admin/lib/format-pageview-count";
import DTooltip from "discourse/float-kit/components/d-tooltip";

export default <template>
  {{#if (isPageviewCountRounded @value)}}
    <DTooltip @content={{formatExactPageviewCount @value}}>
      <:trigger>{{yield (formatPageviewCount @value)}}</:trigger>
    </DTooltip>
  {{else}}
    {{yield (formatPageviewCount @value)}}
  {{/if}}
</template>
