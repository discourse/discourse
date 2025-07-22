import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PostList from "discourse/components/post-list";
import bodyClass from "discourse/helpers/body-class";
import categoryBadge from "discourse/helpers/category-badge";
import dIcon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import { clipboardCopy } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import DoughnutChart from "discourse/plugins/discourse-ai/discourse/components/doughnut-chart";
import AiSentimentHorizontalBar from "../components/ai-sentiment-horizontal-bar";

export default class AdminReportSentimentAnalysis extends Component {
  @service router;

  @tracked selectedChart = null;
  @tracked posts = [];
  @tracked hasMorePosts = false;
  @tracked nextOffset = 0;
  @tracked showingSelectedChart = false;
  @tracked activeFilter = "all";
  @tracked shareIcon = "link";

  setActiveFilter = modifier((element) => {
    this.clearActiveFilters(element);
    element
      .querySelector(`li[data-filter-type="${this.activeFilter}"] button`)
      .classList.add("active");
  });

  clearActiveFilters(element) {
    const filterButtons = element.querySelectorAll("li button");
    for (let button of filterButtons) {
      button.classList.remove("active");
    }
  }

  calculateNeutralScore(data) {
    return data.total_count - (data.positive_count + data.negative_count);
  }

  sentimentMapping(sentiment) {
    switch (sentiment) {
      case "positive":
        return {
          id: "positive",
          text: i18n(
            "discourse_ai.sentiments.sentiment_analysis.filter_types.positive"
          ),
          icon: "face-smile",
        };
      case "neutral":
        return {
          id: "neutral",
          text: i18n(
            "discourse_ai.sentiments.sentiment_analysis.filter_types.neutral"
          ),
          icon: "face-meh",
        };
      case "negative":
        return {
          id: "negative",
          text: i18n(
            "discourse_ai.sentiments.sentiment_analysis.filter_types.negative"
          ),
          icon: "face-angry",
        };
    }
  }

  get groupingType() {
    const dataSample = this.args.model.data[0];
    const localePrefix =
      "discourse_ai.sentiments.sentiment_analysis.group_types";
    return dataSample.category_name
      ? i18n(`${localePrefix}.category`)
      : i18n(`${localePrefix}.tag`);
  }

  get colors() {
    return ["#2ecc71", "#95a5a6", "#e74c3c"];
  }

  get currentGroupFilter() {
    return this.args.model.available_filters.find(
      (filter) => filter.id === "group_by"
    ).default;
  }

  get currentSortFilter() {
    return this.args.model.available_filters.find(
      (filter) => filter.id === "sort_by"
    ).default;
  }

  get transformedData() {
    return this.args.model.data.map((data) => {
      return {
        category: Category.findById(data.category_id),
        title: data.category_name || data.tag_name,
        scores: [
          data.positive_count,
          this.calculateNeutralScore(data),
          data.negative_count,
        ],
        score_map: {
          positive: data.positive_count,
          neutral: this.calculateNeutralScore(data),
          negative: data.negative_count,
        },
        total_score: data.total_count,
        widths: {
          positive: (data.positive_count / data.total_count) * 100,
          neutral: (this.calculateNeutralScore(data) / data.total_count) * 100,
          negative: (data.negative_count / data.total_count) * 100,
        },
      };
    });
  }

  get filteredPosts() {
    if (!this.posts || !this.posts.length) {
      return [];
    }

    return this.posts.filter((post) => {
      post.topic_title = replaceEmoji(post.topic_title);
      post.category = Category.findById(post.category_id);

      if (this.activeFilter === "all") {
        return true;
      }
      return post.sentiment === this.activeFilter;
    });
  }

  get postFilters() {
    return [
      {
        id: "all",
        text: `${i18n(
          "discourse_ai.sentiments.sentiment_analysis.filter_types.all"
        )} (${this.selectedChart.total_score})`,
        icon: "bars-staggered",
        action: () => {
          this.activeFilter = "all";
        },
      },
      {
        id: "positive",
        text: `${i18n(
          "discourse_ai.sentiments.sentiment_analysis.filter_types.positive"
        )} (${this.selectedChart.scores[0]})`,
        icon: "face-smile",
        action: () => {
          this.activeFilter = "positive";
        },
      },
      {
        id: "neutral",
        text: `${i18n(
          "discourse_ai.sentiments.sentiment_analysis.filter_types.neutral"
        )} (${this.selectedChart.scores[1]})`,
        icon: "face-meh",
        action: () => {
          this.activeFilter = "neutral";
        },
      },
      {
        id: "negative",
        text: `${i18n(
          "discourse_ai.sentiments.sentiment_analysis.filter_types.negative"
        )} (${this.selectedChart.scores[2]})`,
        icon: "face-angry",
        action: () => {
          this.activeFilter = "negative";
        },
      },
    ];
  }

  async postRequest() {
    return await ajax("/discourse-ai/sentiment/posts", {
      data: {
        group_by: this.currentGroupFilter,
        group_value: this.selectedChart?.title,
        start_date: this.args.model.start_date,
        end_date: this.args.model.end_date,
        offset: this.nextOffset,
      },
    });
  }

  @action
  async openToChart() {
    const queryParams = this.router.currentRoute.queryParams;
    if (queryParams.selectedChart) {
      this.selectedChart = this.transformedData.find(
        (data) => data.title === queryParams.selectedChart
      );

      if (!this.selectedChart) {
        return;
      }
      this.showingSelectedChart = true;

      try {
        const response = await this.postRequest();
        this.posts = response.posts.map((post) => Post.create(post));
        this.hasMorePosts = response.has_more;
        this.nextOffset = response.next_offset;
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  @action
  async showDetails(data) {
    if (this.selectedChart === data) {
      // Don't do anything if the same chart is clicked again
      return;
    }

    const currentQueryParams = this.router.currentRoute.queryParams;

    const currentFilters = currentQueryParams?.filters
      ? JSON.parse(currentQueryParams.filters)
      : {};

    this.router.transitionTo(this.router.currentRoute.name, {
      queryParams: {
        ...currentQueryParams,
        filters: currentFilters, // avoids a double escaping
        selectedChart: data.title,
      },
    });

    this.selectedChart = data;
    this.showingSelectedChart = true;

    try {
      const response = await this.postRequest();
      this.posts = response.posts.map((post) => Post.create(post));
      this.hasMorePosts = response.has_more;
      this.nextOffset = response.next_offset;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async fetchMorePosts() {
    if (!this.hasMorePosts || this.selectedChart === null) {
      return [];
    }

    try {
      const response = await this.postRequest();

      this.hasMorePosts = response.has_more;
      this.nextOffset = response.next_offset;

      const mappedPosts = response.posts.map((post) => Post.create(post));
      this.posts.pushObjects(mappedPosts);
      return mappedPosts;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  backToAllCharts() {
    this.showingSelectedChart = false;
    this.selectedChart = null;
    this.activeFilter = "all";
    this.posts = [];

    const currentQueryParams = this.router.currentRoute.queryParams;
    const currentFilters = currentQueryParams?.filters
      ? JSON.parse(currentQueryParams.filters)
      : {};
    this.router.transitionTo(this.router.currentRoute.name, {
      queryParams: {
        ...currentQueryParams,
        filters: currentFilters, // avoids a double escaping
        selectedChart: null,
      },
    });
  }

  @action
  shareChart() {
    const url = this.router.currentURL;
    if (!url) {
      return;
    }

    clipboardCopy(getAbsoluteURL(url));
    this.shareIcon = "check";

    discourseLater(() => {
      this.shareIcon = "link";
    }, 2000);
  }

  <template>
    <span {{didInsert this.openToChart}}></span>

    {{#unless this.showingSelectedChart}}
      <div class="admin-report-sentiment-analysis">
        <table class="sentiment-analysis-table md-table">
          <thead>
            <th>{{this.groupingType}}</th>
            <th>{{i18n
                "discourse_ai.sentiments.sentiment_analysis.table.total_count"
              }}</th>
            <th>{{i18n
                "discourse_ai.sentiments.sentiment_analysis.table.sentiment"
              }}</th>
          </thead>

          <tbody>
            {{#each this.transformedData as |data|}}
              <tr
                class="sentiment-analysis-table__row"
                role="button"
                {{on "click" (fn this.showDetails data)}}
              >
                <td class="sentiment-analysis-table__title">
                  {{#if data.category}}
                    {{categoryBadge data.category}}
                  {{else}}
                    {{data.title}}
                  {{/if}}
                </td>
                <td
                  class="sentiment-analysis-table__total-score"
                >{{data.total_score}}</td>
                <td class="sentiment-horizontal-bar">
                  <AiSentimentHorizontalBar
                    @type="positive"
                    @score={{data.score_map.positive}}
                    @width={{data.widths.positive}}
                  />
                  <AiSentimentHorizontalBar
                    @type="negative"
                    @score={{data.score_map.negative}}
                    @width={{data.widths.negative}}
                  />
                  <AiSentimentHorizontalBar
                    @type="neutral"
                    @score={{data.score_map.neutral}}
                    @width={{data.widths.neutral}}
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </div>
    {{/unless}}

    {{#if (and this.selectedChart this.showingSelectedChart)}}
      {{bodyClass "showing-sentiment-analysis-chart"}}
      <div class="admin-report-sentiment-analysis__selected-chart">
        <div class="admin-report-sentiment-analysis__selected-chart-actions">
          <DButton
            @label="back_button"
            @icon="chevron-left"
            class="btn-flat"
            @action={{this.backToAllCharts}}
          />

          <DTooltip
            class="share btn-flat"
            @icon={{this.shareIcon}}
            {{on "click" this.shareChart}}
            @content={{i18n
              "discourse_ai.sentiments.sentiment_analysis.share_chart"
            }}
          />
        </div>

        <DoughnutChart
          @labels={{@model.labels}}
          @colors={{this.colors}}
          @data={{this.selectedChart.scores}}
          @totalScore={{this.selectedChart.total_score}}
          @doughnutTitle={{this.selectedChart.title}}
          @displayLegend={{true}}
        />

      </div>
      <div class="admin-report-sentiment-analysis-details">
        <HorizontalOverflowNav
          {{this.setActiveFilter}}
          class="admin-report-sentiment-analysis-details__filters"
        >
          {{#each this.postFilters as |filter|}}
            <li data-filter-type={{filter.id}}>
              <DButton
                @icon={{filter.icon}}
                @translatedLabel={{filter.text}}
                @action={{filter.action}}
                class="btn-transparent"
              />
            </li>
          {{/each}}
        </HorizontalOverflowNav>

        <PostList
          @posts={{this.filteredPosts}}
          @urlPath="url"
          @idPath="post_id"
          @titlePath="topic_title"
          @usernamePath="username"
          @fetchMorePosts={{this.fetchMorePosts}}
          class="admin-report-sentiment-analysis-details__post-list"
        >
          <:abovePostItemExcerpt as |post|>
            {{#let (this.sentimentMapping post.sentiment) as |sentiment|}}
              <span
                class="admin-report-sentiment-analysis-details__post-score"
                data-sentiment-score={{sentiment.id}}
              >
                {{dIcon sentiment.icon}}
                {{sentiment.text}}
              </span>
            {{/let}}
          </:abovePostItemExcerpt>
        </PostList>
      </div>
    {{/if}}
  </template>
}
