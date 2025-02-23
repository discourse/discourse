{{#if this.model.canLoadMore}}
  {{hide-application-footer}}
{{/if}}

{{body-class "users-page"}}
<section>
  <LoadMore
    @selector=".directory-table .directory-table__cell"
    @action={{action "loadMore"}}
  >
    <div class="container">
      <div class="users-directory directory">
        <span>
          <PluginOutlet
            @name="users-top"
            @connectorTagName="div"
            @outletArgs={{hash model=this.model}}
          />
        </span>
        <div class="directory-controls">
          <div class="period-controls">
            <PeriodChooser
              @period={{this.period}}
              @onChange={{fn (mut this.period)}}
              @fullDay={{false}}
            />
            {{#if this.lastUpdatedAt}}
              <div class="directory-last-updated">
                {{i18n "directory.last_updated"}}
                {{this.lastUpdatedAt}}
              </div>
            {{/if}}
          </div>
          <div class="inline-form">
            <label class="total-rows">
              {{#if this.model.totalRows}}
                {{i18n "directory.total_rows" count=this.model.totalRows}}
              {{/if}}
            </label>
            <Input
              @value={{readonly this.nameInput}}
              placeholder={{i18n "directory.filter_name"}}
              class="filter-name no-blur"
              {{on "input" (with-event-value this.onUsernameFilterChanged)}}
            />
            {{#if this.showGroupFilter}}
              <ComboBox
                @value={{this.group}}
                @content={{this.groupOptions}}
                @onChange={{this.groupChanged}}
                @options={{hash none="directory.group.all"}}
                class="directory-group-selector"
              />
            {{/if}}
            {{#if this.currentUser.staff}}
              <DButton
                @icon="wrench"
                @action={{this.showEditColumnsModal}}
                class="btn-default open-edit-columns-btn"
              />
            {{/if}}
            <PluginOutlet
              @name="users-directory-controls"
              @outletArgs={{hash model=this.model}}
            />
          </div>
        </div>

        <ConditionalLoadingSpinner @condition={{this.isLoading}}>
          {{#if this.model.length}}
            <DirectoryTable
              @items={{this.model}}
              @columns={{this.columns}}
              @showTimeRead={{this.showTimeRead}}
              @order={{this.order}}
              @updateOrder={{fn (mut this.order)}}
              @asc={{this.asc}}
              @updateAsc={{fn (mut this.asc)}}
            />
            <ConditionalLoadingSpinner @condition={{this.model.loadingMore}} />
          {{else}}
            <div class="empty-state">
              <div class="empty-state-body">
                <p>
                  {{#if this.name}}
                    {{i18n "directory.no_results_with_search"}}
                  {{else}}
                    {{i18n "directory.no_results.body"}}
                    {{#if this.currentUser.staff}}
                      {{html-safe
                        (i18n
                          "directory.no_results.extra_body" basePath=(base-path)
                        )
                      }}
                    {{/if}}
                  {{/if}}
                </p>
              </div>
            </div>
          {{/if}}
        </ConditionalLoadingSpinner>
      </div>
    </div>
  </LoadMore>
</section>