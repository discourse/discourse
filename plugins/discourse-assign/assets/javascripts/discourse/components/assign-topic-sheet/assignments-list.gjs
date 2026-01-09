import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DSheet from "discourse/float-kit/components/d-sheet";
import formatUsername from "discourse/helpers/format-username";
import DiscourseURL from "discourse/lib/url";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function navigateToAssignment(topic, assignment) {
  let url = `/t/${topic.slug}/${topic.id}`;

  if (assignment.targetType !== "Topic") {
    url += `/${assignment.postNumber}`;
  }

  DiscourseURL.routeTo(url);
}

const AssignmentCard = <template>
  <div class="assignments-list__card">
    <div class="assignments-list__card-header">
      <button
        type="button"
        class="assignments-list__card-content"
        {{on "click" (fn navigateToAssignment @topic @assignment)}}
      >
        {{#if (eq @assignment.targetType "Topic")}}
          <span class="assignments-list__title">{{@topic.title}}</span>
          {{#if @assignment.username}}
            <span class="assignments-list__username">
              @{{formatUsername @assignment.username}}
            </span>
          {{else if @assignment.groupName}}
            <span class="assignments-list__username">{{@assignment.groupName}}</span>
          {{/if}}
        {{else}}
          <span class="assignments-list__title">
            {{i18n "discourse_assign.post_number" number=@assignment.postNumber}}
          </span>
          {{#if @assignment.username}}
            <span class="assignments-list__username">
              @{{formatUsername @assignment.username}}
            </span>
          {{else if @assignment.groupName}}
            <span class="assignments-list__username">{{@assignment.groupName}}</span>
          {{/if}}
        {{/if}}
      </button>

      <div class="assignments-list__actions">
        <DButton
          class="btn-flat btn-small assignments-list__action-btn"
          @icon="pencil"
          @action={{fn @onEditAssignment @assignment}}
        />
        <DButton
          class="btn-flat btn-small assignments-list__action-btn"
          @icon="user-xmark"
          @action={{fn @onRemoveAssignment @assignment}}
        />
      </div>
    </div>

    {{#if @assignment.note}}
      <div class="assignments-list__note">{{@assignment.note}}</div>
    {{/if}}
  </div>
</template>;

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
