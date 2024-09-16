<div class="themes-list-header">
  <DButton
    @action={{fn this.changeView this.THEMES}}
    @label="admin.customize.theme.title"
    class={{concat-class "themes-tab" "tab" (if this.themesTabActive "active")}}
  />
  <DButton
    @action={{fn this.changeView this.COMPONENTS}}
    @label="admin.customize.theme.components"
    @icon="puzzle-piece"
    class={{concat-class
      "components-tab"
      "tab"
      (if this.componentsTabActive "active")
    }}
  />
</div>

{{#if this.showSearchAndFilter}}
  <div class="themes-list-search">
    <Input
      class="themes-list-search__input"
      placeholder={{i18n "admin.customize.theme.search_placeholder"}}
      autocomplete="off"
      @type="search"
      @value={{mut this.searchTerm}}
    />
    {{d-icon "magnifying-glass"}}
  </div>
  <div class="themes-list-filter">
    <div class="themes-list-filter__label">
      {{i18n "admin.customize.theme.filter_by"}}
    </div>
    <ComboBox
      @content={{this.selectableFilters}}
      @value={{this.filter}}
      class="themes-list-filter__input"
    />
  </div>
{{/if}}
<div class="themes-list-container">
  {{#if this.hasThemes}}
    {{#if (and this.hasActiveThemes (not this.inactiveFilter))}}
      {{#each this.activeThemes as |theme|}}
        <ThemesListItem
          @theme={{theme}}
          @navigateToTheme={{fn this.navigateToTheme theme}}
        />
      {{/each}}

      {{#if (and this.hasInactiveThemes (not this.activeFilter))}}
        <div class="themes-list-container__item inactive-indicator">
          <span class="empty">
            <div class="info">
              {{#if this.selectInactiveMode}}
                <Input
                  @type="checkbox"
                  @checked={{or
                    (eq this.allInactiveSelected true)
                    (eq this.someInactiveSelected true)
                  }}
                  class="toggle-all-inactive"
                  indeterminate={{this.someInactiveSelected}}
                  {{on "click" this.toggleAllInactive}}
                />
              {{else}}
                <DButton
                  class="btn-transparent select-inactive-mode"
                  @action={{this.toggleInactiveMode}}
                >
                  {{d-icon "list"}}
                </DButton>
              {{/if}}
              {{#if this.selectInactiveMode}}
                <span class="select-inactive-mode-label">
                  {{i18n
                    "admin.customize.theme.selected"
                    count=this.selectedCount
                  }}
                </span>
              {{else if this.themesTabActive}}
                <span class="header">
                  {{i18n "admin.customize.theme.inactive_themes"}}
                </span>
              {{else}}
                <span class="header">
                  {{i18n "admin.customize.theme.inactive_components"}}
                </span>
              {{/if}}

              {{#if this.selectInactiveMode}}
                <a
                  href
                  {{on "click" this.toggleInactiveMode}}
                  class="cancel-select-inactive-mode"
                >
                  {{i18n "admin.customize.theme.cancel"}}
                </a>
                <DButton
                  class="btn btn-delete"
                  @action={{this.deleteConfirmation}}
                  @disabled={{eq this.selectedCount 0}}
                >
                  {{d-icon "trash-can"}}
                  Delete
                </DButton>
              {{/if}}
            </div>
          </span>
        </div>
      {{/if}}
    {{/if}}

    {{#if (and this.hasInactiveThemes (not this.activeFilter))}}
      {{#each this.inactiveThemes as |theme|}}
        <ThemesListItem
          class="inactive-theme"
          @theme={{theme}}
          @navigateToTheme={{fn this.navigateToTheme theme}}
          @selectInactiveMode={{this.selectInactiveMode}}
        />
      {{/each}}
    {{/if}}
  {{else}}
    <div class="themes-list-container__item">
      <span class="empty">{{i18n "admin.customize.theme.empty"}}</span>
    </div>
  {{/if}}
</div>

<div class="create-actions">
  <DButton
    @action={{this.installModal}}
    @icon="upload"
    @label="admin.customize.install"
    class="btn-primary"
  />
</div>