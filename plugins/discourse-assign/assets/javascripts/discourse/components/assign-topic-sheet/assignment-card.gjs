import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
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
  <div class="assignment-card">
    <div class="assignment-card__header">
      <button
        type="button"
        class="assignment-card__content"
        {{on "click" (fn navigateToAssignment @topic @assignment)}}
      >
        {{#if (eq @assignment.targetType "Topic")}}
          <span class="assignment-card__title">{{@topic.title}}</span>
          {{#if @assignment.username}}
            <span class="assignment-card__username">
              @{{formatUsername @assignment.username}}
            </span>
          {{else if @assignment.groupName}}
            <span class="assignment-card__username">{{@assignment.groupName}}</span>
          {{/if}}
        {{else}}
          <span class="assignment-card__title">
            {{i18n "discourse_assign.post_number" number=@assignment.postNumber}}
          </span>
          {{#if @assignment.username}}
            <span class="assignment-card__username">
              @{{formatUsername @assignment.username}}
            </span>
          {{else if @assignment.groupName}}
            <span class="assignment-card__username">{{@assignment.groupName}}</span>
          {{/if}}
        {{/if}}
      </button>

      <div class="assignment-card__actions">
        <DButton
          class="btn-flat btn-small assignment-card__action-btn"
          @icon="pencil"
          @action={{fn @onEditAssignment @assignment}}
        />
        <DButton
          class="btn-flat btn-small assignment-card__action-btn"
          @icon="user-xmark"
          @action={{fn @onRemoveAssignment @assignment}}
        />
      </div>
    </div>

    {{#if @assignment.note}}
      <div class="assignment-card__note">{{@assignment.note}}</div>
    {{/if}}
  </div>
</template>;

export default AssignmentCard;
