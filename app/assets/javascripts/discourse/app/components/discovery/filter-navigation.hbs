{{body-class "navigation-filter"}}

<section class="navigation-container">
  <div class="topic-query-filter">
    {{#if (and this.site.mobileView @canBulkSelect)}}
      <div class="topic-query-filter__bulk-action-btn">
        <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
      </div>
    {{/if}}

    <div class="topic-query-filter__input">
      {{d-icon "filter" class="topic-query-filter__icon"}}
      <Input
        class="topic-query-filter__filter-term"
        @value={{this.newQueryString}}
        @enter={{action @updateTopicsListQueryParams this.newQueryString}}
        @type="text"
        id="queryStringInput"
        autocomplete="off"
      />
      {{! EXPERIMENTAL OUTLET - don't use because it will be removed soon  }}
      <PluginOutlet
        @name="below-filter-input"
        @outletArgs={{hash
          updateQueryString=this.updateQueryString
          newQueryString=this.newQueryString
        }}
      />
    </div>
    {{#if this.newQueryString}}
      <div class="topic-query-filter__controls">
        <DButton
          @icon="xmark"
          @action={{this.clearInput}}
          @disabled={{unless this.newQueryString "true"}}
        />

        {{#if this.discoveryFilter.q}}
          <DButton
            @icon={{this.copyIcon}}
            @action={{this.copyQueryString}}
            @disabled={{unless this.newQueryString "true"}}
            class={{this.copyClass}}
          />
        {{/if}}
      </div>
    {{/if}}
  </div>
</section>