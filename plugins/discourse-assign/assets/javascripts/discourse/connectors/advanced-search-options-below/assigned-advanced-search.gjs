import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default class AssignedAdvancedSearch extends Component {
  static shouldRender(args, { currentUser }) {
    return currentUser?.can_assign_globally;
  }

  @service siteSettings;

  @action
  onChangeAssigned(value) {
    this.args.onChangeSearchedTermField(
      "assigned",
      "updateSearchTermForAssignedUsername",
      value
    );
  }

  <template>
    <div class="assigned-advanced-search" ...attributes>
      <div class="control-group">
        <label
          class="control-label"
          for="search-assigned-to"
          id="search-assigned-to-label"
        >
          {{i18n "search.advanced.assigned.label"}}
        </label>

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectUser
              @ariaLabelledBy="search-assigned-to-label"
              @clearable={{true}}
              @id="search-assigned-to"
              @includeGroups="visible"
              @onChange={{legacyPickOne this.onChangeAssigned}}
              @searchOptions={{hash assignableGroups=true}}
              @value={{@searchedTerms.assigned}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <EmailGroupUserChooser
              @onChange={{this.onChangeAssigned}}
              @options={{hash
                maximum=1
                excludeCurrentUser=false
                includeGroups=true
                customSearchOptions=(hash assignableGroups=true)
              }}
              @value={{@searchedTerms.assigned}}
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
