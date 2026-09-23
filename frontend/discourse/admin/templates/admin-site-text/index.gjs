import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import SiteTextSummary from "discourse/admin/components/site-text-summary";
import ComboBox from "discourse/select-kit/components/combo-box";
import { not } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.site_texts.header_description"}}
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.site_texts.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.site_texts.title"}}
        @path="/admin/customize/site_texts"
      />
    </:breadcrumbs>
    <:actions as |actions|>
      <actions.Default
        @action={{@controller.showReseedModal}}
        @icon="arrows-rotate"
        @label="admin.reseed.action.label"
        @title="admin.reseed.action.title"
      />
    </:actions>
  </DPageHeader>

  <div class="search-area">
    <DFilterControls
      @additionalFiltersActive={{@controller.hasActiveFilters}}
      @filterDropdownsExpanded={{@controller.hasActiveFilters}}
      @forceShowDropdownFilterToggle={{true}}
      @showNoResults={{false}}
      @showResetButton={{false}}
      @showTextFilter={{false}}
      @toggleLabel={{@controller.filterLabel}}
    >
      <:inlineFilters>
        <div class="site-texts__search">
          <label for="site-text-search">{{i18n
              "admin.site_text.search_label"
            }}</label>
          <DFilterInput
            class="site-text-search"
            id="site-text-search"
            placeholder={{i18n "admin.site_text.search"}}
            @filterAction={{@controller.updateSearch}}
            @icons={{hash left="magnifying-glass"}}
            @value={{@controller.q}}
          />
        </div>
        <div class="site-texts__language">
          <label id="site-text-language-label">{{i18n
              "admin.site_text.locale"
            }}</label>
          <ComboBox
            class="locale-search"
            @content={{@controller.availableLocales}}
            @onChange={{@controller.updateLocale}}
            @options={{hash
              filterable=true
              headerAriaLabel=(i18n "admin.site_text.locale")
            }}
            @value={{@controller.resolvedLocale}}
            @valueProperty="value"
          />
        </div>
      </:inlineFilters>
      <:additionalFilters>
        <div class="filter-options">
          <label class="checkbox-label">
            <input
              checked={{@controller.resolvedOverridden}}
              id="toggle-overridden"
              type="checkbox"
              {{on "click" @controller.toggleOverridden}}
            />
            {{i18n "admin.site_text.show_overriden"}}
          </label>

          <label class="checkbox-label">
            <input
              checked={{@controller.resolvedOutdated}}
              id="toggle-outdated"
              type="checkbox"
              {{on "click" @controller.toggleOutdated}}
            />
            {{i18n "admin.site_text.show_outdated"}}
          </label>

          <label class="checkbox-label">
            <input
              checked={{@controller.resolvedOnlySelectedLocale}}
              id="toggle-only-locale"
              type="checkbox"
              {{on "click" @controller.toggleOnlySelectedLocale}}
            />
            {{i18n "admin.site_text.only_show_selected_locale"}}
          </label>

          {{#if @controller.showUntranslated}}
            <label class="checkbox-label">
              <input
                checked={{@controller.resolvedUntranslated}}
                id="toggle-untranslated"
                type="checkbox"
                {{on "click" @controller.toggleUntranslated}}
              />
              {{i18n "admin.site_text.show_untranslated"}}
            </label>
          {{/if}}
        </div>
        <DButton
          class="btn-flat site-texts__reset-filters"
          @action={{@controller.resetFilters}}
          @disabled={{not @controller.hasActiveFilters}}
          @label="filter_controls.reset"
        />
      </:additionalFilters>
    </DFilterControls>
  </div>

  {{#if @controller.extras.recommended}}
    <p class="site-texts__recommended">{{i18n
        "admin.site_text.recommended"
      }}</p>
  {{/if}}

  <DLoadMore
    class="site-text-list"
    @action={{@controller.loadMore}}
    @enabled={{@controller.canLoadMore}}
    @isLoading={{@controller.searching}}
  >
    {{#each @controller.siteTexts as |siteText|}}
      <SiteTextSummary
        @editAction={{@controller.edit}}
        @searchRegex={{@controller.extras.regex}}
        @siteText={{siteText}}
        @term={{@controller.q}}
      />
    {{else}}
      {{#unless @controller.searching}}
        {{i18n "admin.site_text.no_results"}}
      {{/unless}}
    {{/each}}
    <DConditionalLoadingSpinner @condition={{@controller.searching}} />
  </DLoadMore>
</template>
