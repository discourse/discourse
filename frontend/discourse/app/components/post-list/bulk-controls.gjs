import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

/**
 * Bulk selection controls for PostList component
 *
 * @component PostListBulkControls
 *
 * @args {PostBulkSelectHelper} bulkSelectHelper - The bulk selection helper
 * @args {Array} bulkActions - Array of bulk action objects with label, action, icon properties
 */
export default class PostListBulkControls extends Component {
  get selectedText() {
    const count = this.args.bulkSelectHelper?.selectedCount || 0;
    return i18n("post_list.bulk.selected", { count });
  }

  @action
  async onBulkActionSelect(bulkAction) {
    if (this.dMenu) {
      await this.dMenu.close();
    }

    if (bulkAction.action && this.args.bulkSelectHelper?.selected) {
      bulkAction.action(this.args.bulkSelectHelper.selected);
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <div class="post-list-bulk-controls">
      <div class="post-list-bulk-controls__selection">
        <div class="post-list-bulk-controls__count">
          {{this.selectedText}}
        </div>

        <div class="post-list-bulk-controls__actions">
          <DButton
            @action={{@bulkSelectHelper.clearAll}}
            @label="post_list.bulk.clear_all"
            class="btn-transparent bulk-clear-all"
          />
          <DButton
            @action={{@bulkSelectHelper.selectAll}}
            @label="post_list.bulk.select_all"
            class="btn-transparent bulk-select-all"
          />

          {{#if @bulkSelectHelper.hasSelection}}
            <DMenu
              @label={{i18n "post_list.bulk.actions"}}
              @placement="bottom"
              @icon="chevron-down"
              @modalForMobile={{true}}
              @autofocus={{true}}
              @identifier="post-list-bulk-actions-dropdown"
              @onRegisterApi={{this.onRegisterApi}}
              class="bulk-actions-dropdown"
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#each @bulkActions as |bulkAction|}}
                    <dropdown.item>
                      <DButton
                        @label={{bulkAction.label}}
                        @icon={{bulkAction.icon}}
                        @disabled={{@bulkSelectHelper.loading}}
                        class="btn-transparent {{bulkAction.class}}"
                        @action={{fn this.onBulkActionSelect bulkAction}}
                      />
                    </dropdown.item>
                  {{/each}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
