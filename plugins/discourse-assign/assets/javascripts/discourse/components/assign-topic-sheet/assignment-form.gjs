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

export default class AssignmentForm extends Component {
  @service taskActions;

  @tracked filter;

  isSelected = (assignee) => {
    const currentAssignee = this.args.data.assignee;
    if (!currentAssignee) {
      return false;
    }
    if (assignee.isGroup) {
      return currentAssignee.is_group && currentAssignee.name === assignee.name;
    }
    return (
      currentAssignee.is_user && currentAssignee.username === assignee.username
    );
  };

  @action
  setFilter(event) {
    this.filter = event.target.value;
  }

  get currentAssigneeAsSearchResult() {
    const assignee = this.args.data.assignee;
    if (!assignee) {
      return null;
    }

    if (assignee.is_group) {
      return {
        isGroup: true,
        name: assignee.name,
        full_name: assignee.full_name,
      };
    }

    return {
      username: assignee.username,
      avatar_template: assignee.avatar_template,
      name: assignee.name,
    };
  }

  @action
  async loadAssignees() {
    let results;

    if (!this.filter && this.taskActions.suggestions) {
      results = [...this.taskActions.suggestions];
    } else {
      const searchResults = await userSearch({
        term: this.filter,
        includeGroups: true,
        customSearchOptions: {
          assignableGroups: true,
        },
      });

      if (typeof searchResults === "string") {
        return;
      }

      results = searchResults;
    }

    const currentAssignee = this.currentAssigneeAsSearchResult;
    if (currentAssignee) {
      // Remove current assignee from list if present, then prepend
      results = results.filter((item) => {
        if (currentAssignee.isGroup) {
          return !(item.isGroup && item.name === currentAssignee.name);
        }
        return item.username !== currentAssignee.username;
      });
      results = [currentAssignee, ...results];
    }

    return results;
  }

  isAssigneeInList(assignee, list) {
    return list.some((item) => {
      if (assignee.isGroup) {
        return item.isGroup && item.name === assignee.name;
      }
      return item.username === assignee.username;
    });
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
          class="assign-sheet__nested-form"
          @controller={{controller}}
        >
          <FilterInput
            @filterAction={{this.setFilter}}
            @icons={{hash left="magnifying-glass"}}
            placeholder={{i18n "discourse_assign.assign_to"}}
          />

          <div class="assign-sheet__assignees-list">
            <AsyncContent @asyncData={{this.loadAssignees}}>
              <:content as |assignees|>
                {{#each assignees as |assignee|}}
                  <AssigneeRow
                    @onPress={{fn this.onSelectAssignee assignee}}
                    @assignee={{assignee}}
                    @selected={{this.isSelected assignee}}
                    @disclosureIndicatorIcon={{if
                      (this.isSelected assignee)
                      "check"
                    }}
                  />
                {{/each}}
              </:content>
            </AsyncContent>
          </div>

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
