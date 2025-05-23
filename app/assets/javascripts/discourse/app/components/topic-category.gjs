import Component from "@ember/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import boundCategoryLink from "discourse/helpers/bound-category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";

// Injections don't occur without a class
export default class TopicCategory extends Component {
  <template>
    {{#unless this.topic.isPrivateMessage}}
      {{boundCategoryLink
        this.topic.category
        ancestors=this.topic.category.predecessors
        hideParent=true
      }}
    {{/unless}}
    <div class="topic-header-extra">
      {{#if this.siteSettings.tagging_enabled}}
        <div class="list-tags">
          {{discourseTags this.topic mode="list" tags=this.topic.tags}}
        </div>
      {{/if}}
      {{#if this.siteSettings.topic_featured_link_enabled}}
        {{topicFeaturedLink this.topic}}
      {{/if}}
    </div>

    <span>
      <PluginOutlet
        @name="topic-category"
        @connectorTagName="div"
        @outletArgs={{lazyHash topic=this.topic category=this.topic.category}}
      />
    </span>
  </template>
}
