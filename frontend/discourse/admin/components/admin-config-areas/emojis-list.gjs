import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/ui-kit/d-button";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import { i18n } from "discourse-i18n";

const ALL_GROUPS = "all";

export default class AdminConfigAreasEmojisList extends Component {
  @service adminEmojis;

  isEmojiSelected = (name) => {
    return this.adminEmojis.selectedEmojis.has(name);
  };

  allVisibleSelected = (emojis) => {
    return (
      emojis.length > 0 &&
      emojis.every((emoji) =>
        this.adminEmojis.selectedEmojis.has(emoji.get("name"))
      )
    );
  };

  someVisibleSelected = (emojis) => {
    return (
      !this.allVisibleSelected(emojis) &&
      emojis.some((emoji) =>
        this.adminEmojis.selectedEmojis.has(emoji.get("name"))
      )
    );
  };

  get emojis() {
    return this.adminEmojis.emojis;
  }

  get searchableProps() {
    return ["name"];
  }

  get groupFilterOptions() {
    return [
      {
        value: ALL_GROUPS,
        label: i18n("admin.emoji.all_groups"),
      },
      ...this.adminEmojis.emojiGroups.map((group) => ({
        value: group,
        label: group,
        filterFn: (emoji) => emoji.group === group,
      })),
    ];
  }

  <template>
    {{#if this.emojis}}
      <DFilterControls
        @array={{this.emojis}}
        @searchableProps={{this.searchableProps}}
        @dropdownOptions={{this.groupFilterOptions}}
        @inputPlaceholder={{i18n "admin.emoji.filter_placeholder"}}
        @noResultsMessage={{i18n "admin.emoji.no_results"}}
      >
        <:actions>
          {{#if this.adminEmojis.isSelecting}}
            <DButton
              @action={{this.adminEmojis.exportSelected}}
              @translatedLabel={{this.adminEmojis.exportLabel}}
              @icon="download"
              @disabled={{this.adminEmojis.exportDisabled}}
              @isLoading={{this.adminEmojis.isExporting}}
              class="btn-primary admin-emoji-list__export-btn"
            />
            <DButton
              @action={{this.adminEmojis.cancelSelecting}}
              @label="cancel"
              class="btn-default admin-emoji-list__cancel-btn"
            />
          {{else}}
            <DButton
              @action={{this.adminEmojis.startSelecting}}
              @label="admin.emoji.select_to_export"
              @icon="download"
              class="btn-default admin-emoji-list__select-to-export"
            />
          {{/if}}
        </:actions>

        <:content as |filteredEmojis|>
          <table id="custom_emoji" class="d-table admin-emoji-list">
            <thead class="d-table__header">
              <tr class="d-table__row">
                {{#if this.adminEmojis.isSelecting}}
                  <th class="d-table__header-cell admin-emoji-list__select-col">
                    <input
                      type="checkbox"
                      class="admin-emoji-list__select-all"
                      aria-label={{i18n "admin.emoji.select_all"}}
                      checked={{this.allVisibleSelected filteredEmojis}}
                      indeterminate={{this.someVisibleSelected filteredEmojis}}
                      {{on
                        "change"
                        (fn this.adminEmojis.toggleAllVisible filteredEmojis)
                      }}
                    />
                  </th>
                {{/if}}
                <th class="d-table__header-cell">{{i18n
                    "admin.emoji.image"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "admin.emoji.name"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "admin.emoji.group"
                  }}</th>
                <th class="d-table__header-cell" colspan="3">{{i18n
                    "admin.emoji.created_by"
                  }}</th>
              </tr>
            </thead>
            <tbody class="d-table__body">
              {{#each filteredEmojis as |emoji|}}
                <tr class="d-table__row">
                  {{#if this.adminEmojis.isSelecting}}
                    <td class="d-table__cell admin-emoji-list__select-col">
                      <input
                        type="checkbox"
                        class="admin-emoji-list__select"
                        aria-label={{i18n "admin.emoji.select" name=emoji.name}}
                        checked={{this.isEmojiSelected emoji.name}}
                        {{on
                          "change"
                          (fn this.adminEmojis.toggleEmojiSelected emoji)
                        }}
                      />
                    </td>
                  {{/if}}
                  <td class="d-table__cell --overview">
                    <img
                      class="emoji emoji-custom"
                      src={{emoji.url}}
                      title={{emoji.name}}
                      alt={{i18n "admin.emoji.alt"}}
                    />
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "admin.emoji.name"}}
                    </div>
                    :{{emoji.name}}:
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "admin.emoji.group"}}
                    </div>
                    {{emoji.group}}
                  </td>
                  <td class="d-table__cell --detail">
                    <div class="d-table__mobile-label">
                      {{i18n "admin.emoji.created_by"}}
                    </div>
                    {{emoji.created_by}}
                  </td>
                  {{#unless this.adminEmojis.isSelecting}}
                    <td class="d-table__cell --controls action">
                      <DButton
                        @action={{fn this.adminEmojis.destroyEmoji emoji}}
                        @label="admin.emoji.delete"
                        class="btn-default btn-small d-table__cell-action-delete"
                      />
                    </td>
                  {{/unless}}
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
      </DFilterControls>
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaLabel="admin.emoji.add"
        @ctaRoute="adminEmojis.new"
        @ctaClass="admin-emoji__add-emoji"
        @emptyLabel="admin.emoji.no_emoji"
      />
    {{/if}}
  </template>
}
