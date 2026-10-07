import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "discourse/truth-helpers";
import DUserStat from "discourse/ui-kit/d-user-stat";

export default class SolvedCount extends Component {
  @service siteSettings;

  <template>
    {{#if
      (and this.siteSettings.solved_enabled @outletArgs.model.solved_count)
    }}
      <li class="user-summary-stat-outlet solved-count linked-stat">
        <LinkTo @route="userActivity.solved">
          <DUserStat
            @icon="square-check"
            @label="solved.solution_summary"
            @value={{@outletArgs.model.solved_count}}
          />
        </LinkTo>
      </li>
    {{/if}}
  </template>
}
