<div class="search-area">
  <TextField
    @value={{this.q}}
    @placeholderKey="admin.site_text.search"
    @autofocus="true"
    @key-up={{this.search}}
    class="no-blur site-text-search"
  />

  <div class="reseed">
    <DButton
      @action={{this.showReseedModal}}
      @label="admin.reseed.action.label"
      @title="admin.reseed.action.title"
      @icon="arrows-rotate"
      class="btn-default"
    />
  </div>

  <p class="filter-options">
    <div class="locale">
      <label>{{i18n "admin.site_text.locale"}}</label>
      <ComboBox
        @valueProperty="value"
        @content={{this.availableLocales}}
        @value={{this.resolvedLocale}}
        @onChange={{this.updateLocale}}
        @options={{hash filterable=true}}
        class="locale-search"
      />
    </div>

    <label class="checkbox-label">
      <input
        id="toggle-overridden"
        type="checkbox"
        checked={{this.resolvedOverridden}}
        {{on "click" this.toggleOverridden}}
      />
      {{i18n "admin.site_text.show_overriden"}}
    </label>

    <label class="checkbox-label">
      <input
        id="toggle-outdated"
        type="checkbox"
        checked={{this.resolvedOutdated}}
        {{on "click" this.toggleOutdated}}
      />
      {{i18n "admin.site_text.show_outdated"}}
    </label>

    <label class="checkbox-label">
      <input
        id="toggle-only-locale"
        type="checkbox"
        checked={{this.resolvedOnlySelectedLocale}}
        {{on "click" this.toggleOnlySelectedLocale}}
      />
      {{i18n "admin.site_text.only_show_selected_locale"}}
    </label>

    {{#if this.showUntranslated}}
      <label class="checkbox-label">
        <input
          id="toggle-untranslated"
          type="checkbox"
          checked={{this.resolvedUntranslated}}
          {{on "click" this.toggleUntranslated}}
        />
        {{i18n "admin.site_text.show_untranslated"}}
      </label>
    {{/if}}
  </p>
</div>

<ConditionalLoadingSpinner @condition={{this.searching}}>
  {{#if this.model.extras.recommended}}
    <p><b>{{i18n "admin.site_text.recommended"}}</b></p>
  {{/if}}

  {{#each this.model as |siteText|}}
    <SiteTextSummary
      @siteText={{siteText}}
      @editAction={{this.edit}}
      @term={{this.q}}
      @searchRegex={{this.model.extras.regex}}
    />
  {{else}}
    {{i18n "admin.site_text.no_results"}}
  {{/each}}

  {{#if this.model.extras.has_more}}
    <p class="warning">{{i18n "admin.site_text.more_than_50_results"}}</p>
  {{/if}}
</ConditionalLoadingSpinner>