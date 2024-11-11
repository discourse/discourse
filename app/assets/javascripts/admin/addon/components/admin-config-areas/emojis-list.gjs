import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import ComboBox from "select-kit/components/combo-box";

export default class AdminConfigAreasEmojisList extends Component {
  @service dialog;
  @service adminEmojis;

  get filteredEmojis() {
    return this.adminEmojis.filteredEmojis;
  }

  get sortedEmojis() {
    return this.adminEmojis.sortedEmojis;
  }

  get emojiGroups() {
    return this.adminEmojis.emojiGroups;
  }

  get sortingGroups() {
    return this.adminEmojis.sortingGroups;
  }

  <template>
    <div class="form-horizontal">
      <div class="inline-form">
        <ComboBox
          @value={{this.adminEmojis.filter}}
          @content={{this.sortingGroups}}
          @nameProperty={{null}}
          @valueProperty={{null}}
        />
      </div>
    </div>

    {{#if this.sortedEmojis}}
      <table id="custom_emoji" class="d-admin-table">
        <thead>
          <tr>
            <th>{{i18n "admin.emoji.image"}}</th>
            <th>{{i18n "admin.emoji.name"}}</th>
            <th>{{i18n "admin.emoji.group"}}</th>
            <th colspan="3">{{i18n "admin.emoji.created_by"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each this.sortedEmojis as |emoji|}}
            <tr class="d-admin-row__content">
              <td class="d-admin-row__overview">
                <img
                  class="emoji emoji-custom"
                  src={{emoji.url}}
                  title={{emoji.name}}
                  alt={{i18n "admin.emoji.alt"}}
                />
              </td>
              <td class="d-admin-row__detail">
                <div class="d-admin-row__mobile-label">
                  {{i18n "admin.emoji.name"}}
                </div>
                :{{emoji.name}}:
              </td>
              <td class="d-admin-row__detail">
                <div class="d-admin-row__mobile-label">
                  {{i18n "admin.emoji.group"}}
                </div>
                {{emoji.group}}
              </td>
              <td class="d-admin-row__detail">
                <div class="d-admin-row__mobile-label">
                  {{i18n "admin.emoji.created_by"}}
                </div>
                {{emoji.created_by}}
              </td>
              <td class="d-admin-row__controls action">
                <DButton
                  @action={{fn this.adminEmojis.destroyEmoji emoji}}
                  @icon="trash-can"
                  class="btn-small"
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{/if}}
  </template>
}
