import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import concatClass from "discourse/helpers/concat-class";
import DButton from "discourse/components/d-button";
import formatUsername from "discourse/helpers/format-username";
import DiscourseURL from "discourse/lib/url";
import { eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function navigateToAssignment(topic, assignment) {
  let url = `/t/${topic.slug}/${topic.id}`;

  if (assignment.targetType !== "Topic") {
    url += `/${assignment.postNumber}`;
  }

  DiscourseURL.routeTo(url);
}

const AssignmentCard = <template>
  <div
    class={{concatClass
      "assignment-card"
      (if
        (or @assignment.username @assignment.groupName)
        ""
        "--unassigned"
      )
    }}
  >
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
          {{else}}
            <span class="assignment-card__unassigned">
              {{i18n "discourse_assign.unassigned"}}
            </span>
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
        {{#if (or @assignment.username @assignment.groupName)}}
          <DButton
            class="btn-flat btn-small assignment-card__action-btn"
            @icon="user-xmark"
            @action={{fn @onRemoveAssignment @assignment}}
          />
        {{/if}}
      </div>
    </div>

    {{#if @assignment.note}}
      <div class="assignment-card__note">{{@assignment.note}}</div>
    {{/if}}
  </div>
</template>;

export default AssignmentCard;
