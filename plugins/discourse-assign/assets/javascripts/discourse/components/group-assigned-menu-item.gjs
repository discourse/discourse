import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const GroupAssignedMenuItem = <template>
  <LinkTo @route="group.assigned">
    {{dIcon "group-plus" class="glyph"}}{{i18n "discourse_assign.assigned"}}
    ({{@group.assignment_count}})
  </LinkTo>
</template>;

export default GroupAssignedMenuItem;
