import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

@classNames("assigned-advanced-search")
export default class AssignedAdvancedSearch extends Component {
  static shouldRender(args, component) {
    return component.currentUser?.can_assign;
  }

  @service currentUser;

  @action
  onChangeAssigned(value) {
    this.outletArgs.onChangeSearchedTermField(
      "assigned",
      "updateSearchTermForAssignedUsername",
      value
    );
  }

  <template>
    <div class="control-group">
      <label class="control-label" for="search-assigned-to">
        {{i18n "search.advanced.assigned.label"}}
      </label>

      <div class="controls">
        <EmailGroupUserChooser
          @value={{this.outletArgs.searchedTerms.assigned}}
          @onChange={{this.onChangeAssigned}}
          @options={{hash
            maximum=1
            excludeCurrentUser=false
            includeGroups=true
            customSearchOptions=(hash assignableGroups=true)
          }}
        />
      </div>
    </div>
  </template>
}
