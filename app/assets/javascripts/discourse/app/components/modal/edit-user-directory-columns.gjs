<DModal
  @closeModal={{@closeModal}}
  @title={{i18n "directory.edit_columns.title"}}
  class="edit-user-directory-columns-modal"
  @flash={{this.flash}}
>
  <:body>
    {{#if this.loading}}
      {{loading-spinner size="large"}}
    {{else}}
      <div class="edit-directory-columns-container">
        {{#each this.columns as |column|}}
          <div class="edit-directory-column">
            <div class="left-content">
              <label class="column-name">
                <Input @type="checkbox" @checked={{column.enabled}} />
                {{#if (directory-column-is-automatic column=column)}}
                  {{directory-table-header-title
                    field=column.name
                    labelKey=this.labelKey
                    icon=column.icon
                  }}
                {{else if (directory-column-is-user-field column=column)}}
                  {{directory-table-header-title
                    field=column.user_field.name
                    translated=true
                  }}
                {{else}}
                  {{directory-table-header-title
                    field=(i18n column.name)
                    translated=true
                  }}
                {{/if}}
              </label>
            </div>
            <div class="right-content">
              <DButton
                @icon="arrow-up"
                @action={{fn this.moveUp column}}
                class="button-secondary move-column-up"
              />
              <DButton
                @icon="arrow-down"
                @action={{fn this.moveDown column}}
                class="button-secondary"
              />
            </div>
          </div>
        {{/each}}
      </div>
    {{/if}}
  </:body>
  <:footer>
    <DButton
      @label="directory.edit_columns.save"
      @action={{this.save}}
      class="btn-primary"
    />
    <DButton
      @label="directory.edit_columns.reset_to_default"
      @action={{this.resetToDefault}}
      class="btn-secondary reset-to-default"
    />
  </:footer>
</DModal>