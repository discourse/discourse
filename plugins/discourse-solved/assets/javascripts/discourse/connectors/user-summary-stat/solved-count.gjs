import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import UserStat from "discourse/components/user-stat";

export default class SolvedCount extends Component {
  @service siteSettings;

  <template>
    {{#if
      (and this.siteSettings.solved_enabled @outletArgs.model.solved_count)
    }}
      <li class="user-summary-stat-outlet solved-count linked-stat">
        <LinkTo @route="userActivity.solved">
          <UserStat
            @value={{@outletArgs.model.solved_count}}
            @label="solved.solution_summary"
            @icon="square-check"
          />
        </LinkTo>
      </li>
    {{/if}}
  </template>
}
