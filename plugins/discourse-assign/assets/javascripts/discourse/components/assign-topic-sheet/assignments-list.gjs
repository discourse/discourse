import { hash } from "@ember/helper";
import DSheet from "discourse/float-kit/components/d-sheet";
import AssignmentCard from "./assignment-card";

const AssignmentsList = <template>
  <DSheet.Scroll.Root as |controller|>
    <DSheet.Scroll.View
      @scrollGestureTrap={{hash yEnd=true}}
      @safeArea="layout-viewport"
      @onScrollStart={{hash dismissKeyboard=true}}
      @controller={{controller}}
    >
      <DSheet.Scroll.Content
        class="assignments-list"
        @controller={{controller}}
      >
        {{#each @assignments as |assignment|}}
          <AssignmentCard
            @assignment={{assignment}}
            @topic={{@topic}}
            @onEditAssignment={{@onEditAssignment}}
            @onRemoveAssignment={{@onRemoveAssignment}}
          />
        {{/each}}
      </DSheet.Scroll.Content>
    </DSheet.Scroll.View>
  </DSheet.Scroll.Root>
</template>;

export default AssignmentsList;
