import Component from "@glimmer/component";
import DStatTiles from "discourse/ui-kit/d-stat-tiles";
import { i18n } from "discourse-i18n";

export default class WorkflowStats extends Component {
  get showAiUsage() {
    return (
      this.args.stats?.ai_usage &&
      this.args.workflow?.nodes?.some((node) => node.type === "action:ai_agent")
    );
  }

  <template>
    {{#if (or @stats.total this.showAiUsage)}}
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
        {{#if this.showAiUsage}}
          <tiles.Tile
            @formattedValue={{@stats.ai_usage.requests}}
            @label={{i18n "discourse_workflows.stats.ai_requests"}}
          />
          <tiles.Tile
            @formattedValue={{@stats.ai_usage.tokens}}
            @label={{i18n "discourse_workflows.stats.ai_tokens"}}
          />
          <tiles.Tile
            @formattedValue={{@stats.ai_usage.estimated_cost}}
            @label={{i18n "discourse_workflows.stats.ai_estimated_cost"}}
          />
        {{/if}}
      </DStatTiles>
    {{/if}}
  </template>
}
