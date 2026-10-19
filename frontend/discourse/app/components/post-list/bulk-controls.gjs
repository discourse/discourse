import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

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
            class="btn-transparent bulk-clear-all"
            @action={{@bulkSelectHelper.clearAll}}
            @label="post_list.bulk.clear_all"
          />
          <DButton
            class="btn-transparent bulk-select-all"
            @action={{@bulkSelectHelper.selectAll}}
            @label="post_list.bulk.select_all"
          />

          {{#if @bulkSelectHelper.hasSelection}}
            <DMenu
              class="bulk-actions-dropdown"
              @autofocus={{true}}
              @icon="chevron-down"
              @identifier="post-list-bulk-actions-dropdown"
              @label={{i18n "post_list.bulk.actions"}}
              @modalForMobile={{true}}
              @onRegisterApi={{this.onRegisterApi}}
              @placement="bottom"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  {{#each @bulkActions as |bulkAction|}}
                    <dropdown.item>
                      <DButton
                        class="btn-transparent {{bulkAction.class}}"
                        @action={{fn this.onBulkActionSelect bulkAction}}
                        @disabled={{@bulkSelectHelper.loading}}
                        @icon={{bulkAction.icon}}
                        @label={{bulkAction.label}}
                      />
                    </dropdown.item>
                  {{/each}}
                </DDropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
