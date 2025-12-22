import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DSheet from "discourse/float-kit/components/d-sheet";

const AssignmentsList = <template>
  <DSheet.Scroll.Root as |controller|>
    <DSheet.Scroll.View
      @scrollGestureTrap={{hash yEnd=true}}
      @safeArea="layout-viewport"
      @onScrollStart={{hash dismissKeyboard=true}}
      @controller={{controller}}
    >
      <DSheet.Scroll.Content
        class="SheetWithDetent-scrollContent"
        @controller={{controller}}
      >
        {{#each @assignments as |assignment|}}
          <button
            type="button"
            class="assign-sheet__assignee"
            {{on "click" (fn @onSelectAssignment assignment)}}
          >
            {{assignment.targetType}}
            -
            {{assignment.targetId}}
          </button>
        {{/each}}
      </DSheet.Scroll.Content>
    </DSheet.Scroll.View>
  </DSheet.Scroll.Root>
</template>;

export default AssignmentsList;
