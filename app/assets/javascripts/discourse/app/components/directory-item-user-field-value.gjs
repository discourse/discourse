import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";

export default class DirectoryItemUserFieldValueComponent extends Component {
  @service router;
  get fieldData() {
    const { item, column } = this.args;
    return item?.user?.user_fields?.[column.user_field_id];
  }

  get values() {
    const fieldData = this.fieldData;
    if (!fieldData || !fieldData.value) {
      return null;
    }

    return fieldData.value
      .toString()
      .split(",")
      .map((v) => v.replace(/-/g, " "))
      .map((v) => v.trim());
  }

  get isSearchable() {
    return this.fieldData?.searchable;
  }

  @action
  refreshRoute(value) {
    this.router.transitionTo({ queryParams: { name: value } });
  }

  <template>
    <span class="directory-table__value--user-field">
      {{#if this.values}}
        {{#if this.isSearchable}}
          {{#each this.values as |value|}}
            <LinkTo
              @route="users"
              @query={{hash name=value}}
              {{on "click" (fn this.refreshRoute value)}}
              class="directory-value-list-item"
            >{{value}}</LinkTo>
          {{/each}}
        {{else}}
          {{this.values}}
        {{/if}}
      {{else}}
        -
      {{/if}}
    </span>
  </template>
}
