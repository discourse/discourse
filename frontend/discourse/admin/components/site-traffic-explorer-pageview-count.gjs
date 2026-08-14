import {
  formatExactPageviewCount,
  formatPageviewCount,
} from "discourse/admin/lib/format-pageview-count";

export default <template>
  <span
    class="fk-d-tooltip__trigger"
    title={{formatExactPageviewCount @value}}
  ><span class="fk-d-tooltip__trigger-container">{{yield
        (formatPageviewCount @value)
      }}</span></span>
</template>
