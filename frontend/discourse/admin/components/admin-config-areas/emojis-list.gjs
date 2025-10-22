import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import ComboBox from "select-kit/components/combo-box";

export default class AdminConfigAreasEmojisList extends Component {
  @service adminEmojis;

  get emojis() {
    return this.adminEmojis.emojis;
  }

  get sortedEmojis() {
    return this.adminEmojis.sortedEmojis;
  }

  get filteringGroups() {
    return this.adminEmojis.filteringGroups;
  }

  <template>
    <div class="form-horizontal">
      <div class="inline-form">
        <ComboBox
          @value={{this.adminEmojis.filter}}
          @content={{this.filteringGroups}}
          @nameProperty={{null}}
          @valueProperty={{null}}
        />
      </div>
    </div>

    {{#if this.emojis}}
      <table id="custom_emoji" class="d-table">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">{{i18n "admin.emoji.image"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.emoji.name"}}</th>
            <th class="d-table__header-cell">{{i18n "admin.emoji.group"}}</th>
            <th class="d-table__header-cell" colspan="3">{{i18n
                "admin.emoji.created_by"
              }}</th>
          </tr>
        </thead>
        {{#if this.sortedEmojis}}
          <tbody class="d-table__body">
            {{#each this.sortedEmojis as |emoji|}}
              <tr class="d-table__row">
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
                <td class="d-table__cell --controls action">
                  <DButton
                    @action={{fn this.adminEmojis.destroyEmoji emoji}}
                    @label="admin.emoji.delete"
                    class="btn-default btn-small d-table__cell-action-delete"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        {{/if}}
      </table>
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
