import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatUsername from "discourse/helpers/format-username";
import { i18n } from "discourse-i18n";

const GroupAssignedFilter = <template>
  <li>
    {{#if @showAvatar}}
      <LinkTo
        @route="group.assigned.show"
        @model={{@filter.username_lower}}
        @query={{hash order=@order ascending=@ascending search=@search}}
      >
        <div class="assign-image">
          <a
            href={{@filter.userPath}}
            data-user-card={{@filter.username}}
          >{{avatar this.filter imageSize="large"}}</a>
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
        @route="group.assigned.show"
        @model={{@filter}}
        @query={{hash order=@order ascending=@ascending search=@search}}
      >
        <div class="assign-image">
          {{icon "group-plus"}}
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
        @route="group.assigned.show"
        @model={{@filter}}
        @query={{hash order=@order ascending=@ascending search=@search}}
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
