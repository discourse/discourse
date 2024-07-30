import { or } from "truth-helpers";

const GroupsInfo = <template>
  <span class="group-info-details">
    <span class="groups-info-name">
      {{or @group.full_name @group.displayName}}
    </span>
  </span>
</template>;

export default GroupsInfo;
