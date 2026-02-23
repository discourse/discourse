import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import SiteTextSummary from "discourse/admin/components/site-text-summary";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import TextField from "discourse/components/text-field";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="search-area">
    <TextField
      @value={{@controller.q}}
      @placeholderKey="admin.site_text.search"
      @autofocus="true"
      @key-up={{@controller.search}}
      class="no-blur site-text-search"
    />

    <div class="reseed">
      <DButton
        @action={{@controller.showReseedModal}}
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
          @content={{@controller.availableLocales}}
          @value={{@controller.resolvedLocale}}
          @onChange={{@controller.updateLocale}}
          @options={{hash filterable=true}}
          class="locale-search"
        />
      </div>

      <label class="checkbox-label">
        <input
          id="toggle-overridden"
          type="checkbox"
          checked={{@controller.resolvedOverridden}}
          {{on "click" @controller.toggleOverridden}}
        />
        {{i18n "admin.site_text.show_overriden"}}
      </label>

      <label class="checkbox-label">
        <input
          id="toggle-outdated"
          type="checkbox"
          checked={{@controller.resolvedOutdated}}
          {{on "click" @controller.toggleOutdated}}
        />
        {{i18n "admin.site_text.show_outdated"}}
      </label>

      <label class="checkbox-label">
        <input
          id="toggle-only-locale"
          type="checkbox"
          checked={{@controller.resolvedOnlySelectedLocale}}
          {{on "click" @controller.toggleOnlySelectedLocale}}
        />
        {{i18n "admin.site_text.only_show_selected_locale"}}
      </label>

      {{#if @controller.showUntranslated}}
        <label class="checkbox-label">
          <input
            id="toggle-untranslated"
            type="checkbox"
            checked={{@controller.resolvedUntranslated}}
            {{on "click" @controller.toggleUntranslated}}
          />
          {{i18n "admin.site_text.show_untranslated"}}
        </label>
      {{/if}}
    </p>
  </div>

  {{#if @controller.extras.recommended}}
    <p><b>{{i18n "admin.site_text.recommended"}}</b></p>
  {{/if}}

  <LoadMore
    @action={{@controller.loadMore}}
    @enabled={{@controller.canLoadMore}}
    @isLoading={{@controller.searching}}
    class="site-text-list"
  >
    {{#each @controller.siteTexts as |siteText|}}
      <SiteTextSummary
        @siteText={{siteText}}
        @editAction={{@controller.edit}}
        @term={{@controller.q}}
        @searchRegex={{@controller.extras.regex}}
      />
    {{else}}
      {{#unless @controller.searching}}
        {{i18n "admin.site_text.no_results"}}
      {{/unless}}
    {{/each}}
    <ConditionalLoadingSpinner @condition={{@controller.searching}} />
  </LoadMore>
</template>
