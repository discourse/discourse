import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class GroupedAssignsDropdown extends Component {
  get assignments() {
    return this.args.data?.assignments || [];
  }

  get assigneeName() {
    return this.args.data?.assigneeName;
  }

  get topicId() {
    return this.args.data?.topicId;
  }

  @action
  goToAssignment(assignment) {
    let url;
    if (assignment.postId) {
      url = getURL(`/p/${assignment.postId}`);
    } else if (assignment.isTopicLevel) {
      url = getURL(`/t/${this.topicId}`);
    }

    this.args.close?.();

    if (url) {
      DiscourseURL.routeTo(url);
    }
  }

  <template>
    <div class="grouped-assigns-dropdown-content">
      <div class="dropdown-header">
        <span class="assignee-name">{{this.assigneeName}}</span>
        <span class="assignment-count">{{i18n
            "discourse_assign.grouped_assigns.count"
            count=this.assignments.length
          }}</span>
      </div>
      <ul class="assignments-list">
        {{#each this.assignments as |assignment|}}
          <li class="assignment-item">
            <button
              type="button"
              class="btn-flat assignment-link"
              {{on "click" (fn this.goToAssignment assignment)}}
            >
              {{#if assignment.postId}}
                {{i18n
                  "discourse_assign.grouped_assigns.post_number"
                  number=assignment.postNumber
                }}
              {{else}}
                {{i18n "discourse_assign.grouped_assigns.topic_level"}}
              {{/if}}
            </button>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
