import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import HighlightedSearch from "discourse/components/search-menu/highlighted-search";
import Blurb from "discourse/components/search-menu/results/blurb";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import { and } from "discourse/truth-helpers";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export default class Results extends Component {
  @service siteSettings;

  get shouldShowPrivateMessageIcon() {
    // Only show PM icon if this is a PM AND we're not in a PM-only search
    return this.args.result.topic.isPrivateMessage && !this.args.isPMOnly;
  }

  <template>
    <span class="topic">
      <span class="first-line">
        <TopicStatus
          @topic={{@result.topic}}
          @disableActions={{true}}
          @context="topic-view-title"
          @showPrivateMessageIcon={{this.shouldShowPrivateMessageIcon}}
        />
        <span class="topic-title" data-topic-id={{@result.topic.id}}>
          {{#if
            (and
              this.siteSettings.use_pg_headlines_for_excerpt
              @result.topic_title_headline
            )
          }}
            <a href={{if @withTopicUrl @result.url}}>
              {{dReplaceEmoji (trustHTML @result.topic_title_headline)}}
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
        {{dCategoryLink
          @result.topic.category
          link=(if @withTopicUrl true false)
        }}
        {{#if this.siteSettings.tagging_enabled}}
          {{dDiscourseTags @result.topic tagName="span"}}
        {{/if}}
      </span>
    </span>
    <Blurb @result={{@result}} />
  </template>
}
