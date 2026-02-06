import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import DSheet from "discourse/float-kit/components/d-sheet";
import AssigneeRow from "./assignee-row";

export default class AssignmentForm extends Component {
  <template>
    <DSheet.Scroll.Root as |controller|>
      <DSheet.Scroll.View
        @scrollGestureTrap={{hash yEnd=true}}
        @safeArea="layout-viewport"
        @onScrollStart={{hash dismissKeyboard=true}}
        @controller={{controller}}
      >
        <DSheet.Scroll.Content
          class="assign-sheet__nested-form"
          @controller={{controller}}
        >
          <AssigneeRow
            @assignee={{@data.assignee}}
            @onPress={{@onShowAssigneesList}}
            @disclosureIndicatorIcon="chevron-right"
          >
            Choose assignee...
          </AssigneeRow>

          <@form.Field
            @name="note"
            @title="note"
            @showTitle={{false}}
            class="assign-sheet__note-field"
            @format="full"
            as |field|
          >
            <field.Textarea placeholder="Optional note" />
          </@form.Field>
        </DSheet.Scroll.Content>
      </DSheet.Scroll.View>
    </DSheet.Scroll.Root>
  </template>
}
