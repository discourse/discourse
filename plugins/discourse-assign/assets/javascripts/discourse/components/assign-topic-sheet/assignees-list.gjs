import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import FilterInput from "discourse/components/filter-input";
import DSheet from "discourse/float-kit/components/d-sheet";
import userSearch from "discourse/lib/user-search";
import { i18n } from "discourse-i18n";
import AssigneeRow from "./assignee-row";

export default class AssigneesList extends Component {
  @service taskActions;

  @tracked filter;

  @action
  setFilter(event) {
    this.filter = event.target.value;
  }

  @action
  async loadAssignees() {
    if (!this.filter && this.taskActions.suggestions) {
      return Promise.resolve(
        this.taskActions.suggestions.filter((suggestion) => {
          return suggestion.username !== this.args.data.assignee?.username;
        })
      );
    }

    const results = await userSearch({
      term: this.filter,
      includeGroups: true,
      customSearchOptions: {
        assignableGroups: true,
      },
    });

    if (typeof results === "string") {
      // do nothing promise probably got cancelled
    } else {
      return results;
    }
  }

  @action
  onSelectAssignee(assignee) {
    if (assignee.isGroup) {
      this.args.form.set("assignee", {
        is_group: true,
        name: assignee.name,
        full_name: assignee.full_name,
      });
    } else {
      this.args.form.set("assignee", {
        is_user: true,
        name: assignee.name,
        username: assignee.username,
        avatar_template: assignee.avatar_template,
      });
    }

    this.args.sheet.close();
  }

  <template>
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
          <div class="assign-sheet__assignees-list">
            <FilterInput
              @filterAction={{this.setFilter}}
              @icons={{hash left="magnifying-glass"}}
              placeholder={{i18n "discourse_assign.assign_to"}}
            />

            <AsyncContent @asyncData={{this.loadAssignees}}>
              <:content as |assignees|>
                {{#each assignees as |assignee|}}
                  <AssigneeRow
                    @onPress={{fn this.onSelectAssignee assignee}}
                    @assignee={{assignee}}
                    @disclosureIndicatorIcon="check"
                  />
                {{/each}}
              </:content>
            </AsyncContent>
          </div>
        </DSheet.Scroll.Content>
      </DSheet.Scroll.View>
    </DSheet.Scroll.Root>
  </template>
}
