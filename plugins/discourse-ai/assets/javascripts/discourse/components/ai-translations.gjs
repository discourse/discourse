import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DStatTiles from "discourse/components/d-stat-tiles";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "discourse/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ComboBox from "select-kit/components/combo-box";
import Chart from "admin/components/chart";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";

export default class AiTranslations extends Component {
  @tracked loadingData = false;

  get chartConfig() {
    // TODO: Replace with actual chart configuration
  }

  <template>
    <div class="ai-translations admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.translations.title"}}
        @descriptionLabel={{i18n "discourse_ai.translations.description"}}
        @learnMoreUrl="https://meta.discourse.org/t/-/370969"
      />
    </div>

    <ConditionalLoadingSpinner @condition={{this.loadingData}}>
      {{log @model}}

      {{#if @model.length}}
        <AdminConfigAreaCard
          class="ai-translation__charts"
          @heading="discourse_ai.translations.translation_progress"
        >
          <:content>
            <div class="ai-translation__chart-container">
              <Chart
                @chartConfig={{this.chartConfig}}
                class="ai-translation__chart"
              />
            </div>
          </:content>
        </AdminConfigAreaCard>

        <AdminConfigAreaCard
          class="ai-translation__table"
          @heading="discourse_ai.translations.language_status"
        >
          <:content>
            <table class="ai-translation__languages-table">
              <thead>
                <tr>
                  <th>{{i18n "discourse_ai.translations.language"}}</th>
                  <th>{{i18n "discourse_ai.translations.locale"}}</th>
                  <th>{{i18n "discourse_ai.translations.completion"}}</th>
                  <th>{{i18n "discourse_ai.translations.posts_remaining"}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each @model as |item|}}
                  <tr>
                    <td>{{item.language}}</td>
                    <td>{{item.locale}}</td>
                    <td>{{item.completion_percentage}}%</td>
                    <td>{{item.todo_count}}</td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </:content>
        </AdminConfigAreaCard>
      {{else}}
        <div class="empty-state">
          <p>{{i18n "discourse_ai.translations.no_languages"}}</p>
        </div>
      {{/if}}
    </ConditionalLoadingSpinner>
  </template>
}
