import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import DirectoryTable from "discourse/components/directory-table";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import PeriodChooser from "discourse/select-kit/components/period-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.model.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}

  {{bodyClass "users-page"}}
  <section>
    <DLoadMore
      @action={{@controller.loadMore}}
      @enabled={{@controller.model.canLoadMore}}
      @isLoading={{@controller.isLoading}}
    >
      <div class="container">
        <div class="users-directory directory">
          <span>
            <PluginOutlet
              @connectorTagName="div"
              @name="users-top"
              @outletArgs={{lazyHash model=@controller.model}}
            />
          </span>
          <div class="directory-controls">
            <div class="period-controls">
              <PeriodChooser
                @fullDay={{false}}
                @onChange={{fn (mut @controller.period)}}
                @period={{@controller.period}}
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
                class="filter-name no-blur"
                placeholder={{i18n "directory.filter_name"}}
                @value={{readonly @controller.nameInput}}
                {{on
                  "input"
                  (withEventValue @controller.onUsernameFilterChanged)
                }}
              />
              {{#if @controller.showGroupFilter}}
                <ComboBox
                  class="directory-group-selector"
                  @content={{@controller.groupOptions}}
                  @onChange={{@controller.groupChanged}}
                  @options={{hash none="directory.group.all"}}
                  @value={{@controller.group}}
                />
              {{/if}}
              {{#if @controller.currentUser.staff}}
                <DButton
                  class="btn-default open-edit-columns-btn"
                  @action={{@controller.showEditColumnsModal}}
                  @icon="wrench"
                />
              {{/if}}
              <PluginOutlet
                @name="users-directory-controls"
                @outletArgs={{lazyHash model=@controller.model}}
              />
            </div>
          </div>

          <DConditionalLoadingSpinner @condition={{@controller.isLoading}}>
            {{#if @controller.model.content}}
              <DirectoryTable
                @asc={{@controller.asc}}
                @columns={{@controller.columns}}
                @items={{@controller.model.content}}
                @order={{@controller.order}}
                @showTimeRead={{@controller.showTimeRead}}
                @updateOrderAndAsc={{@controller.updateOrderAndAsc}}
              />
              <DConditionalLoadingSpinner
                @condition={{@controller.model.loadingMore}}
              />
            {{else}}
              <DEmptyState
                @body={{if
                  @controller.name
                  (i18n "directory.no_results_with_search")
                  (if
                    @controller.currentUser.staff
                    (trustHTML
                      (i18n
                        "directory.no_results.extra_body" basePath=(dBasePath)
                      )
                    )
                    (i18n "directory.no_results.body")
                  )
                }}
              />
            {{/if}}
          </DConditionalLoadingSpinner>
        </div>
      </div>
    </DLoadMore>
  </section>
</template>
