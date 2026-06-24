import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { capitalize } from "@ember/string";
import moment from "moment";
import DSegmentedControl from "discourse/components/d-segmented-control";
import KeyValueStore from "discourse/lib/key-value-store";
import Badge from "discourse/models/badge";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";
import { chartability, defaultView, looksLikeDate } from "../lib/chart-helpers";
import DataExplorerChart from "./data-explorer-chart";
import QueryChartEmptyState from "./query-chart-empty-state";
import QueryResultDownloadButtons from "./query-result-download-buttons";
import QueryRowContent from "./query-row-content";
import BadgeViewComponent from "./result-types/badge";
import CategoryViewComponent from "./result-types/category";
import GroupViewComponent from "./result-types/group";
import HtmlViewComponent from "./result-types/html";
import JsonViewComponent from "./result-types/json";
import PostViewComponent from "./result-types/post";
import ReltimeViewComponent from "./result-types/reltime";
import TagGroupViewComponent from "./result-types/tag-group";
import TextViewComponent from "./result-types/text";
import TopicViewComponent from "./result-types/topic";
import UrlViewComponent from "./result-types/url";
import UserViewComponent from "./result-types/user";

const store = new KeyValueStore("discourse_data_explorer_");

const VIEW_COMPONENTS = {
  topic: TopicViewComponent,
  text: TextViewComponent,
  post: PostViewComponent,
  reltime: ReltimeViewComponent,
  badge: BadgeViewComponent,
  url: UrlViewComponent,
  user: UserViewComponent,
  group: GroupViewComponent,
  html: HtmlViewComponent,
  json: JsonViewComponent,
  category: CategoryViewComponent,
  tag_group: TagGroupViewComponent,
};

const CHART_FORMS = ["line", "bar", "stacked", "dual-axis"];

export default class QueryResult extends Component {
  @service site;

  @tracked internalView;
  @tracked internalChartForm;
  @tracked tableExpanded = false;
  @tracked hasOverflow = false;

  constructor() {
    super(...arguments);
    const queryId = this.args.query?.id;

    if (!this.args.view) {
      const stored = queryId ? store.get(`view_${queryId}`) : null;
      if (stored === "chart" || stored === "table") {
        this.internalView = stored;
      } else {
        this.internalView = defaultView(this.args.content);
      }
    }

    const storedChartForm = queryId ? store.get(`chart_form_${queryId}`) : null;
    if (CHART_FORMS.includes(storedChartForm)) {
      this.internalChartForm = storedChartForm;
    }
  }

  get view() {
    return this.args.view ?? this.internalView;
  }

  @action
  setView(value) {
    if (this.args.onSetView) {
      this.args.onSetView(value);
      return;
    }
    this.internalView = value;
    const queryId = this.args.query?.id;
    if (queryId) {
      store.set({ key: `view_${queryId}`, value });
    }
  }

  @action
  viewTable() {
    this.setView("table");
  }

  @action
  setChartForm(value) {
    this.internalChartForm = value;
    const queryId = this.args.query?.id;
    if (queryId) {
      store.set({ key: `chart_form_${queryId}`, value });
    }
  }

  get showExpandButton() {
    return this.hasOverflow && !this.tableExpanded;
  }

  @action
  checkOverflow(element) {
    this.hasOverflow = element.scrollHeight > element.clientHeight;
  }

  @action
  expandTable() {
    this.tableExpanded = true;
  }

  @cached
  get chartability() {
    return chartability(this.args.content);
  }

  get canShowChart() {
    return this.chartability.chartable;
  }

  get chartVisible() {
    return this.view === "chart" && this.canShowChart;
  }

  get showChartEmptyState() {
    return this.view === "chart" && !this.canShowChart;
  }

  get showTable() {
    return this.view === "table";
  }

  get hasResults() {
    return this.rows?.length > 0;
  }

  get numericColumnIndices() {
    return this.chartability.numericIndices;
  }

  get ignoredColumnNames() {
    return this.chartability.ignoredColumns;
  }

  get ignoredColumnsText() {
    return this.ignoredColumnNames.join(", ");
  }

  get viewItems() {
    return [
      { value: "chart", icon: "signal" },
      { value: "table", icon: "table" },
    ];
  }

  get chartFormItems() {
    const items = [
      { value: "line", label: i18n("explorer.chart.form.line") },
      { value: "bar", label: i18n("explorer.chart.form.bar") },
    ];

    if (this.isMultiSeries) {
      items.push({
        value: "stacked",
        label: i18n("explorer.chart.form.stacked"),
      });
    }

    if (this.canUseDualAxis) {
      items.push({
        value: "dual-axis",
        label: i18n("explorer.chart.form.dual_axis"),
      });
    }

    return items;
  }

  get colRender() {
    return this.args.content.colrender || {};
  }

  get rows() {
    return this.args.content.rows;
  }

  get columns() {
    return this.args.content.columns;
  }

  get explainText() {
    return this.args.content.explain;
  }

  get showDownloads() {
    return this.args.showDownloads !== false;
  }

  get isMultiSeries() {
    return this.numericColumnIndices.length > 1;
  }

  get canUseDualAxis() {
    return this.hasDates && this.numericColumnIndices.length === 2;
  }

  get hasDates() {
    return this.rows?.length > 0 && looksLikeDate(String(this.rows[0][0]));
  }

  get defaultChartForm() {
    if (this.hasDates) {
      return "line";
    }
    return "bar";
  }

  get availableChartForms() {
    return this.chartFormItems.map((item) => item.value);
  }

  get chartForm() {
    if (this.availableChartForms.includes(this.internalChartForm)) {
      return this.internalChartForm;
    }
    return this.defaultChartForm;
  }

  get chartType() {
    return ["line", "dual-axis"].includes(this.chartForm) ? "line" : "bar";
  }

  get isStacked() {
    return this.chartForm === "stacked";
  }

  get usesDualAxis() {
    return this.chartForm === "dual-axis";
  }

  get chartDatasets() {
    return this.numericColumnIndices.map((colIdx) => ({
      label: this.columnNames[colIdx],
      values: this.rows.map((r) => Number(r[colIdx])),
    }));
  }

  get columnNames() {
    if (!this.columns) {
      return [];
    }
    return this.columns.map((colName) => {
      if (colName.endsWith("_id")) {
        return colName.slice(0, -3);
      }
      const dIdx = colName.indexOf("$");
      if (dIdx >= 0) {
        return colName.substring(dIdx + 1);
      }
      return colName;
    });
  }

  get columnComponents() {
    if (!this.columns) {
      return [];
    }
    return this.columns.map((_, idx) => {
      let type = "text";
      if (this.colRender[idx]) {
        type = this.colRender[idx];
      }
      return { name: type, component: VIEW_COMPONENTS[type] };
    });
  }

  get colCount() {
    return this.columns.length;
  }

  get resultCount() {
    const count = this.args.content.result_count;
    if (count === this.args.content.default_limit) {
      return i18n("explorer.max_result_count", { count });
    } else {
      return i18n("explorer.result_count", { count });
    }
  }

  get duration() {
    return i18n("explorer.run_time", {
      value: I18n.toNumber(this.args.content.duration, { precision: 1 }),
    });
  }

  get cachedResultNotice() {
    if (!this.args.cachedAt) {
      return null;
    }
    return i18n("explorer.cached_result_notice", {
      relative_time: moment(this.args.cachedAt).fromNow(),
    });
  }

  get parameterAry() {
    let arr = [];
    for (let key in this.params) {
      if (this.params.hasOwnProperty(key)) {
        arr.push({ key, value: this.params[key] });
      }
    }
    return arr;
  }

  get transformedUserTable() {
    return transformedRelTable(this.args.content.relations.user);
  }

  get transformedBadgeTable() {
    return transformedRelTable(this.args.content.relations.badge, Badge);
  }

  get transformedPostTable() {
    return transformedRelTable(this.args.content.relations.post);
  }

  get transformedTopicTable() {
    return transformedRelTable(this.args.content.relations.topic);
  }

  get transformedTagGroupTable() {
    return transformedRelTable(this.args.content.relations.tag_group);
  }

  get transformedGroupTable() {
    return transformedRelTable(this.site.groups);
  }

  get chartLabels() {
    const labelSelectors = {
      user: (user) => user.username,
      badge: (badge) => badge.name,
      topic: (topic) => topic.title,
      group: (group) => group.name,
      category: (category) => category.name,
    };

    const relationName = this.colRender[0];
    if (relationName) {
      const lookupFunc = this[`lookup${capitalize(relationName)}`];
      const labelSelector = labelSelectors[relationName];

      if (lookupFunc && labelSelector) {
        return this.rows.map((r) => {
          const relation = lookupFunc.call(this, r[0]);
          const label = labelSelector(relation);
          return this._cutChartLabel(label);
        });
      }
    }

    return this.rows.map((r) => this._cutChartLabel(r[0]));
  }

  lookupUser(id) {
    return this.transformedUserTable[id];
  }

  lookupBadge(id) {
    return this.transformedBadgeTable[id];
  }

  lookupPost(id) {
    return this.transformedPostTable[id];
  }

  lookupTopic(id) {
    return this.transformedTopicTable[id];
  }

  lookupTagGroup(id) {
    return this.transformedTagGroupTable[id];
  }

  lookupGroup(id) {
    return this.transformedGroupTable[id];
  }

  lookupCategory(id) {
    return Category.findById(id);
  }

  _cutChartLabel(label) {
    const labelString = String(label ?? "NULL");
    if (labelString.length > 25) {
      return `${labelString.substring(0, 25)}...`;
    } else {
      return labelString;
    }
  }

  <template>
    <article>
      <div class="result-header">
        {{#unless @hideHeaderActions}}
          <div class="result-header__top">
            <div class="result-actions">
              {{#if this.hasResults}}
                <DSegmentedControl
                  @name="query-result-view"
                  @value={{this.view}}
                  @items={{this.viewItems}}
                  @onSelect={{this.setView}}
                  @translatedLabel={{i18n "explorer.view.label"}}
                  class="query-results-modes"
                />
              {{/if}}

              {{#if this.showDownloads}}
                <QueryResultDownloadButtons
                  @query={{@query}}
                  @content={{@content}}
                  @group={{@group}}
                  @includeQueryExport={{@includeQueryExport}}
                />
              {{/if}}
            </div>
          </div>
        {{/unless}}

        <div class="result-meta">
          <div class="result-about">
            {{this.resultCount}}
            {{this.duration}}
          </div>
          {{#if this.cachedResultNotice}}
            <div class="cached-result-notice">
              {{dIcon "clock-rotate-left"}}
              {{this.cachedResultNotice}}
            </div>
          {{/if}}
        </div>

        {{~#if this.explainText}}
          <pre class="result-explain">
        <code>
              {{~this.explainText}}
            </code>
      </pre>
        {{~/if}}
      </div>

      <section>

        {{#if this.chartVisible}}
          <div class="query-results-chart">
            <DSegmentedControl
              @name="query-result-chart-form"
              @value={{this.chartForm}}
              @items={{this.chartFormItems}}
              @onSelect={{this.setChartForm}}
              @translatedLabel={{i18n "explorer.chart.form.label"}}
              @size="small"
              class="query-results-chart__form"
            />

            <DataExplorerChart
              @labels={{this.chartLabels}}
              @datasets={{this.chartDatasets}}
              @chartType={{this.chartType}}
              @stacked={{this.isStacked}}
              @dualAxis={{this.usesDualAxis}}
            />
            {{#if this.ignoredColumnNames.length}}
              <p class="query-results-chart__footnote">
                {{i18n
                  "explorer.chart_footnote.ignored"
                  columns=this.ignoredColumnsText
                }}
              </p>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.showChartEmptyState}}
          <QueryChartEmptyState
            @reason={{this.chartability.reason}}
            @ignoredColumns={{this.chartability.ignoredColumns}}
            @onViewAsTable={{this.viewTable}}
          />
        {{/if}}

        {{#if this.showTable}}
          <div
            class="query-results-table-wrapper
              {{if this.tableExpanded '--expanded'}}"
            {{didInsert this.checkOverflow}}
          >
            <table class="query-results-table">
              <thead>
                <tr class="headers">
                  {{#each this.columnNames as |col|}}
                    <th>{{col}}</th>
                  {{/each}}
                </tr>
              </thead>
              <tbody>
                {{#each this.rows as |row|}}
                  <QueryRowContent
                    @row={{row}}
                    @columnComponents={{this.columnComponents}}
                    @lookupUser={{this.lookupUser}}
                    @lookupBadge={{this.lookupBadge}}
                    @lookupPost={{this.lookupPost}}
                    @lookupTopic={{this.lookupTopic}}
                    @lookupTagGroup={{this.lookupTagGroup}}
                    @lookupGroup={{this.lookupGroup}}
                    @lookupCategory={{this.lookupCategory}}
                    @transformedPostTable={{this.transformedPostTable}}
                    @transformedBadgeTable={{this.transformedBadgeTable}}
                    @transformedUserTable={{this.transformedUserTable}}
                    @transformedTagGroupTable={{this.transformedTagGroupTable}}
                    @transformedGroupTable={{this.transformedGroupTable}}
                    @transformedTopicTable={{this.transformedTopicTable}}
                    @site={{this.site}}
                  />
                {{/each}}
              </tbody>
            </table>
          </div>
          {{#if this.showExpandButton}}
            <DButton
              @action={{this.expandTable}}
              @icon="chevron-down"
              @translatedTitle={{i18n "show_more"}}
              class="btn-flat query-results-expand-btn"
            />
          {{/if}}
        {{/if}}

      </section>
    </article>
  </template>
}

function transformedRelTable(table, modelClass) {
  const result = {};
  table?.forEach((item) => {
    if (modelClass) {
      result[item.id] = modelClass.create(item);
    } else {
      result[item.id] = item;
    }
  });
  return result;
}
