import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DirectoryTable from "discourse/components/directory-table";
import EmptyState from "discourse/components/empty-state";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import basePath from "discourse/helpers/base-path";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import PeriodChooser from "select-kit/components/period-chooser";

export default RouteTemplate(
  <template>
    {{#if @controller.model.canLoadMore}}
      {{hideApplicationFooter}}
    {{/if}}

    {{bodyClass "users-page"}}
    <section>
      <LoadMore
        @action={{@controller.loadMore}}
        @enabled={{@controller.model.canLoadMore}}
        @isLoading={{@controller.isLoading}}
      >
        <div class="container">
          <div class="users-directory directory">
            <span>
              <PluginOutlet
                @name="users-top"
                @connectorTagName="div"
                @outletArgs={{lazyHash model=@controller.model}}
              />
            </span>
            <div class="directory-controls">
              <div class="period-controls">
                <PeriodChooser
                  @period={{@controller.period}}
                  @onChange={{fn (mut @controller.period)}}
                  @fullDay={{false}}
                />
                {{#if @controller.lastUpdatedAt}}
                  <div class="directory-last-updated">
                    {{i18n "directory.last_updated"}}
                    {{@controller.lastUpdatedAt}}
                  </div>
                {{/if}}
              </div>
              <div class="inline-form">
                <label class="total-rows">
                  {{#if @controller.model.totalRows}}
                    {{i18n
                      "directory.total_rows"
                      count=@controller.model.totalRows
                    }}
                  {{/if}}
                </label>
                <Input
                  @value={{readonly @controller.nameInput}}
                  placeholder={{i18n "directory.filter_name"}}
                  class="filter-name no-blur"
                  {{on
                    "input"
                    (withEventValue @controller.onUsernameFilterChanged)
                  }}
                />
                {{#if @controller.showGroupFilter}}
                  <ComboBox
                    @value={{@controller.group}}
                    @content={{@controller.groupOptions}}
                    @onChange={{@controller.groupChanged}}
                    @options={{hash none="directory.group.all"}}
                    class="directory-group-selector"
                  />
                {{/if}}
                {{#if @controller.currentUser.staff}}
                  <DButton
                    @icon="wrench"
                    @action={{@controller.showEditColumnsModal}}
                    class="btn-default open-edit-columns-btn"
                  />
                {{/if}}
                <PluginOutlet
                  @name="users-directory-controls"
                  @outletArgs={{lazyHash model=@controller.model}}
                />
              </div>
            </div>

            <ConditionalLoadingSpinner @condition={{@controller.isLoading}}>
              {{#if @controller.model.length}}
                <DirectoryTable
                  @items={{@controller.model}}
                  @columns={{@controller.columns}}
                  @showTimeRead={{@controller.showTimeRead}}
                  @order={{@controller.order}}
                  @asc={{@controller.asc}}
                  @updateOrderAndAsc={{@controller.updateOrderAndAsc}}
                />
                <ConditionalLoadingSpinner
                  @condition={{@controller.model.loadingMore}}
                />
              {{else}}
                <EmptyState
                  @body={{if
                    @controller.name
                    (i18n "directory.no_results_with_search")
                    (if
                      @controller.currentUser.staff
                      (htmlSafe
                        (i18n
                          "directory.no_results.extra_body" basePath=(basePath)
                        )
                      )
                      (i18n "directory.no_results.body")
                    )
                  }}
                />
              {{/if}}
            </ConditionalLoadingSpinner>
          </div>
        </div>
      </LoadMore>
    </section>
  </template>
);
