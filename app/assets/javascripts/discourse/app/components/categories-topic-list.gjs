import Component from "@ember/component";
import { concat } from "@ember/helper";
import { eq } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import LatestTopicListItem from "discourse/components/topic-list/latest-topic-list-item";
import getUrl from "discourse/helpers/get-url";
import { i18n } from "discourse-i18n";

// Exists so plugins can use it
export default class CategoriesTopicList extends Component {
  <template>
    <div role="heading" aria-level="2" class="table-heading">
      {{i18n (concat "filters." this.filter ".title")}}
      <PluginOutlet
        @name="categories-topics-table-heading"
        @connectorTagName="div"
      />
    </div>

    {{#if this.topics}}
      {{#each this.topics as |t|}}
        <LatestTopicListItem @topic={{t}} />
      {{/each}}

      <div class="more-topics">
        {{#if
          (eq
            this.siteSettings.desktop_category_page_style
            "categories_and_latest_topics_created_date"
          )
        }}
          <a
            href={{getUrl (concat "/" this.filter "?order=created")}}
            class="btn btn-default pull-right"
          >{{i18n "more"}}</a>
        {{else}}
          <a
            href={{getUrl (concat "/" this.filter)}}
            class="btn btn-default pull-right"
          >{{i18n "more"}}</a>
        {{/if}}
      </div>
    {{else}}
      <div class="no-topics">
        <h3>{{i18n (concat "topics.none." this.filter)}}</h3>
      </div>
    {{/if}}
  </template>
}
