import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import HighlightedSearch from "discourse/components/search-menu/highlighted-search";
import Blurb from "discourse/components/search-menu/results/blurb";
import TopicStatus from "discourse/components/topic-status";
import categoryLink from "discourse/helpers/category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import lazyHash from "discourse/helpers/lazy-hash";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class Results extends Component {
  @service siteSettings;

  <template>
    <span class="topic">
      <span class="first-line">
        <TopicStatus
          @topic={{@result.topic}}
          @disableActions={{true}}
          @context="topic-view-title"
        />
        <span class="topic-title" data-topic-id={{@result.topic.id}}>
          {{#if
            (and
              this.siteSettings.use_pg_headlines_for_excerpt
              @result.topic_title_headline
            )
          }}
            <a href={{if @withTopicUrl @result.url}}>
              {{replaceEmoji (htmlSafe @result.topic_title_headline)}}
            </a>
          {{else}}
            <a href={{if @withTopicUrl @result.url}}>
              <HighlightedSearch @string={{@result.topic.fancyTitle}} />
            </a>
          {{/if}}
          <PluginOutlet
            @name="search-menu-results-topic-title-suffix"
            @outletArgs={{lazyHash topic=@result.topic}}
          />
        </span>
      </span>
      <span class="second-line">
        {{categoryLink
          @result.topic.category
          link=(if @withTopicUrl true false)
        }}
        {{#if this.siteSettings.tagging_enabled}}
          {{discourseTags @result.topic tagName="span"}}
        {{/if}}
      </span>
    </span>
    <Blurb @result={{@result}} />
  </template>
}
