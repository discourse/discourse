import DStatTiles from "discourse/ui-kit/d-stat-tiles";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @stats.total}}
    <DStatTiles
      title={{i18n "discourse_workflows.stats.period"}}
      @format="compact"
      as |tiles|
    >
      <tiles.Tile
        @formattedValue={{@stats.total}}
        @label={{i18n "discourse_workflows.stats.executions"}}
      />
      <tiles.Tile
        @formattedValue={{@stats.failed}}
        @label={{i18n "discourse_workflows.stats.failures"}}
      />
      <tiles.Tile
        @formattedValue={{@stats.failure_rate}}
        @label={{i18n "discourse_workflows.stats.failure_rate"}}
      />
      <tiles.Tile
        @formattedValue={{@stats.avg_duration}}
        @label={{i18n "discourse_workflows.stats.avg_run_time"}}
      />
    </DStatTiles>
  {{/if}}
</template>
