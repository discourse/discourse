import { or } from "truth-helpers";
import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";

const GroupsInfo = <template>
  <PluginOutlet
    @name="group-info-details"
    @outletArgs={{hash group=@group}}
    @defaultGlimmer={{true}}
  >
    <span class="group-info-details">
      <span class="groups-info-name">
        {{or @group.full_name @group.displayName}}
      </span>
    </span>
  </PluginOutlet>
</template>;

export default GroupsInfo;
