import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import DirectoryItemUserFieldValue from "discourse/components/directory-item-user-field-value";
import UserInfo from "discourse/components/user-info";
import icon from "discourse/helpers/d-icon";
import directoryColumnIsUserField from "discourse/helpers/directory-column-is-user-field";
import directoryItemLabel from "discourse/helpers/directory-item-label";
import directoryItemValue from "discourse/helpers/directory-item-value";
import formatDuration from "discourse/helpers/format-duration";
import { propertyEqual } from "discourse/lib/computed";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames("directory-table__row")
@classNameBindings("me")
@attributeBindings("role")
export default class DirectoryItem extends Component {
  role = "row";

  @propertyEqual("item.user.id", "currentUser.id") me;
  columns = null;

  <template>
    <div class="directory-table__cell" role="rowheader">
      <UserInfo @user={{this.item.user}} />
    </div>

    {{#each this.columns as |column|}}
      {{#if (directoryColumnIsUserField column=column)}}
        <div class="directory-table__cell--user-field" role="cell">
          <span class="directory-table__label">
            <span>{{column.name}}</span>
          </span>
          <DirectoryItemUserFieldValue @item={{this.item}} @column={{column}} />
        </div>
      {{else}}
        <div class="directory-table__cell" role="cell">
          <span class="directory-table__label">
            <span>
              {{#if column.icon}}
                {{icon column.icon}}
              {{/if}}
              {{directoryItemLabel item=this.item column=column}}
            </span>
          </span>
          {{directoryItemValue item=this.item column=column}}
        </div>
      {{/if}}

    {{/each}}

    {{#if this.showTimeRead}}
      <div class="directory-table__cell time-read" role="cell">
        <span class="directory-table__label">
          <span>{{i18n "directory.time_read"}}</span>
        </span>
        <span class="directory-table__value">
          {{formatDuration this.item.time_read}}
        </span>
      </div>
    {{/if}}
  </template>
}
