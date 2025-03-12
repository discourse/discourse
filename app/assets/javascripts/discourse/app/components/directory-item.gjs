<div class="directory-table__cell" role="rowheader">
  <UserInfo @user={{this.item.user}} />
</div>

{{#each this.columns as |column|}}
  {{#if (directory-column-is-user-field column=column)}}
    <div class="directory-table__cell--user-field" role="cell">
      <span class="directory-table__label">
        <span>{{column.name}}</span>
      </span>
      {{directory-item-user-field-value item=this.item column=column}}
    </div>
  {{else}}
    <div class="directory-table__cell" role="cell">
      <span class="directory-table__label">
        <span>
          {{#if column.icon}}
            {{d-icon column.icon}}
          {{/if}}
          {{directory-item-label item=this.item column=column}}
        </span>
      </span>
      {{directory-item-value item=this.item column=column}}
    </div>
  {{/if}}

{{/each}}

{{#if this.showTimeRead}}
  <div class="directory-table__cell time-read" role="cell">
    <span class="directory-table__label">
      <span>{{i18n "directory.time_read"}}</span>
    </span>
    <span class="directory-table__value">
      {{format-duration this.item.time_read}}
    </span>
  </div>
{{/if}}