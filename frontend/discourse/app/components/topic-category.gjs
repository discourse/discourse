import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import dBoundCategoryLink from "discourse/ui-kit/helpers/d-bound-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";

export default class TopicCategory extends Component {
  @service siteSettings;

  <template>
    <div ...attributes>
      <PluginOutlet
        @name="topic-category-link-wrapper"
        @outletArgs={{lazyHash category=@topic.category topic=@topic}}
      >
        {{#unless @topic.isPrivateMessage}}
          {{dBoundCategoryLink
            @topic.category
            ancestors=@topic.category.predecessors
            hideParent=true
          }}
        {{/unless}}
      </PluginOutlet>
      <div class="topic-header-extra">
        {{#if this.siteSettings.tagging_enabled}}
          <div class="list-tags">
            {{dDiscourseTags @topic mode="list" tags=@topic.tags}}
          </div>
        {{/if}}
        {{#if this.siteSettings.topic_featured_link_enabled}}
          {{topicFeaturedLink @topic}}
        {{/if}}
      </div>

      <span>
        <PluginOutlet
          @connectorTagName="div"
          @name="topic-category"
          @outletArgs={{lazyHash topic=@topic category=@topic.category}}
        />
      </span>
    </div>
  </template>
}
