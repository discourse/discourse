/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import dBoundCategoryLink from "discourse/ui-kit/helpers/d-bound-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";

// Injections don't occur without a class
@tagName("")
export default class TopicCategory extends Component {
  <template>
    <div ...attributes>
      <PluginOutlet
        @name="topic-category-link-wrapper"
        @outletArgs={{lazyHash category=this.topic.category topic=this.topic}}
      >
        {{#unless this.topic.isPrivateMessage}}
          {{dBoundCategoryLink
            this.topic.category
            ancestors=this.topic.category.predecessors
            hideParent=true
          }}
        {{/unless}}
      </PluginOutlet>
      <div class="topic-header-extra">
        {{#if this.siteSettings.tagging_enabled}}
          <div class="list-tags">
            {{dDiscourseTags this.topic mode="list" tags=this.topic.tags}}
          </div>
        {{/if}}
        {{#if this.siteSettings.topic_featured_link_enabled}}
          {{topicFeaturedLink this.topic}}
        {{/if}}
      </div>

      <span>
        <PluginOutlet
          @connectorTagName="div"
          @name="topic-category"
          @outletArgs={{lazyHash topic=this.topic category=this.topic.category}}
        />
      </span>
    </div>
  </template>
}
