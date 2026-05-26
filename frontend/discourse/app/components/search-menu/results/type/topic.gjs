import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import HighlightedSearch from "discourse/components/search-menu/highlighted-search";
import Blurb from "discourse/components/search-menu/results/blurb";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

const MaybeAnchor = <template>
  {{#if @href}}
    <a href={{@href}}>{{yield}}</a>
  {{else}}
    {{yield}}
  {{/if}}
</template>;

export default class Results extends Component {
  @service siteSettings;

  get shouldShowPrivateMessageIcon() {
    // Only show PM icon if this is a PM AND we're not in a PM-only search
    return this.args.result.topic.isPrivateMessage && !this.args.isPMOnly;
  }

  get useHeadline() {
    return (
      this.siteSettings.use_pg_headlines_for_excerpt &&
      this.args.result.topic_title_headline
    );
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
          <MaybeAnchor @href={{if @withTopicUrl @result.url}}>
            {{#if this.useHeadline}}
              {{dReplaceEmoji (trustHTML @result.topic_title_headline)}}
            {{else}}
              <HighlightedSearch @string={{@result.topic.fancyTitle}} />
            {{/if}}
          </MaybeAnchor>
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
