import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import SiteTextSummary from "discourse/admin/components/site-text-summary";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="search-area">
    <DTextField
      class="no-blur site-text-search"
      @autofocus="true"
      @key-up={{@controller.search}}
      @placeholderKey="admin.site_text.search"
      @value={{@controller.q}}
    />

    <div class="reseed">
      <DButton
        class="btn-default"
        @action={{@controller.showReseedModal}}
        @icon="arrows-rotate"
        @label="admin.reseed.action.label"
        @title="admin.reseed.action.title"
      />
    </div>

    <p class="filter-options">
      <div class="locale">
        <label>{{i18n "admin.site_text.locale"}}</label>
        <ComboBox
          class="locale-search"
          @content={{@controller.availableLocales}}
          @onChange={{@controller.updateLocale}}
          @options={{hash filterable=true}}
          @value={{@controller.resolvedLocale}}
          @valueProperty="value"
        />
      </div>

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
    </p>
  </div>

  {{#if @controller.extras.recommended}}
    <p><b>{{i18n "admin.site_text.recommended"}}</b></p>
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
