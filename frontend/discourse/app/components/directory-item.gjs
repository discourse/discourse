import Component from "@glimmer/component";
import { service } from "@ember/service";
import DirectoryItemUserFieldValue from "discourse/components/directory-item-user-field-value";
import directoryColumnIsUserField from "discourse/helpers/directory-column-is-user-field";
import directoryItemLabel from "discourse/helpers/directory-item-label";
import directoryItemValue from "discourse/helpers/directory-item-value";
import { deepEqual } from "discourse/lib/object";
import DUserInfo from "discourse/ui-kit/d-user-info";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DirectoryItem extends Component {
  @service currentUser;

  get me() {
    return deepEqual(this.args.item?.user?.id, this.currentUser?.id);
  }

  <template>
    <div
      class={{dConcatClass "directory-table__row" (if this.me "me")}}
      role="row"
      ...attributes
    >
      <div class="directory-table__cell" role="rowheader">
        <DUserInfo @headingLevel={{3}} @user={{@item.user}} />
      </div>

      {{#each @columns as |column|}}
        {{#if (directoryColumnIsUserField column=column)}}
          <div class="directory-table__cell--user-field" role="cell">
            <span class="directory-table__label">
              <span>{{column.name}}</span>
            </span>
            <DirectoryItemUserFieldValue @column={{column}} @item={{@item}} />
          </div>
        {{else}}
          <div class="directory-table__cell" role="cell">
            <span class="directory-table__label">
              <span>
                {{#if column.icon}}
                  {{dIcon column.icon}}
                {{/if}}
                {{directoryItemLabel item=@item column=column}}
              </span>
            </span>
            {{directoryItemValue item=@item column=column}}
          </div>
        {{/if}}

      {{/each}}

      {{#if @showTimeRead}}
        <div class="directory-table__cell time-read" role="cell">
          <span class="directory-table__label">
            <span>{{i18n "directory.time_read"}}</span>
          </span>
          <span class="directory-table__value">
            {{dFormatDuration @item.time_read}}
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
