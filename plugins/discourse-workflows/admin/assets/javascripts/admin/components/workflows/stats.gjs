import DStatTiles from "discourse/components/d-stat-tiles";
import { i18n } from "discourse-i18n";

<template>
  {{#if @stats.total}}
    <DStatTiles as |tiles|>
      <tiles.Tile
        @label={{i18n "discourse_workflows.stats.executions"}}
        @value={{@stats.total}}
      />
      <tiles.Tile
        @label={{i18n "discourse_workflows.stats.failures"}}
        @value={{@stats.failed}}
      />
      <tiles.Tile
        @label={{i18n "discourse_workflows.stats.failure_rate"}}
        @formattedValue={{@stats.failure_rate}}
      />
      <tiles.Tile
        @label={{i18n "discourse_workflows.stats.avg_run_time"}}
        @formattedValue={{@stats.avg_duration}}
      />
    </DStatTiles>
  {{/if}}
</template>
