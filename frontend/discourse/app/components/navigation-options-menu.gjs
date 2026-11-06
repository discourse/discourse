import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

/**
 * The topic list's less frequent actions, gathered behind one button where
 * the list's views sit beside the mobile tab bar.
 */
export default class NavigationOptionsMenu extends Component {
  get hasOptions() {
    return this.args.showBulkSelect;
  }

  @action
  run(option, menu) {
    menu.close();
    option();
  }

  <template>
    {{#if this.hasOptions}}
      <DMenu
        @ariaLabel={{i18n "topics.list_options"}}
        @icon="ellipsis-vertical"
        @identifier="navigation-options"
        @modalForMobile={{true}}
        @triggerClass="btn-transparent navigation-options__trigger"
      >
        <:content as |menu|>
          <DDropdownMenu as |dropdown|>
            {{#if @showBulkSelect}}
              <dropdown.item>
                <DButton
                  class="btn-transparent navigation-options__bulk-select"
                  @action={{fn
                    this.run
                    @bulkSelectHelper.toggleBulkSelect
                    menu
                  }}
                  @icon="list"
                  @label="topics.bulk.select"
                />
              </dropdown.item>
            {{/if}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
