import { array } from "@ember/helper";
import GroupManageEmailSettings from "discourse/components/group-manage-email-settings";

export default <template>
  {{#each (array @controller.model) as |group|}}
    <GroupManageEmailSettings @group={{group}} />
  {{/each}}
</template>
