import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import formatUsername from "discourse/helpers/format-username";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const GroupAssignedFilter = <template>
  <li>
    {{#if @showAvatar}}
      <LinkTo
        @model={{@filter.username_lower}}
        @query={{hash order=@order ascending=@ascending search=@search}}
        @route="group.assigned.show"
      >
        <div class="assign-image">
          <a data-user-card={{@filter.username}} href={{@filter.userPath}}>
            {{dAvatar @filter imageSize="small"}}
          </a>
        </div>

        <div class="assign-names">
          <div class="assign-username">{{formatUsername @filter.username}}</div>
          <div class="assign-name">{{@filter.name}}</div>
        </div>

        <div class="assign-count">
          {{@filter.assignments_count}}
        </div>
      </LinkTo>
    {{else if @groupName}}
      <LinkTo
        @model={{@filter}}
        @query={{hash order=@order ascending=@ascending search=@search}}
        @route="group.assigned.show"
      >
        <div class="assign-image">
          {{dIcon "group-plus"}}
        </div>
        <div class="assign-names">
          <div class="assign-username">{{@groupName}}</div>
        </div>

        <div class="assign-count">
          {{@assignmentCount}}
        </div>
      </LinkTo>
    {{else}}
      <LinkTo
        @model={{@filter}}
        @query={{hash order=@order ascending=@ascending search=@search}}
        @route="group.assigned.show"
      >
        <div class="assign-everyone">
          {{i18n "discourse_assign.group_everyone"}}
        </div>
        <div class="assign-count">
          {{@assignmentCount}}
        </div>
      </LinkTo>
    {{/if}}
  </li>
</template>;

export default GroupAssignedFilter;
