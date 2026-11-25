import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicMapLink from "discourse/components/topic-map/topic-map-link";
import TopicParticipants from "discourse/components/topic-map/topic-participants";
import lazyHash from "discourse/helpers/lazy-hash";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

const TopicDetails = <template>
  <div class="context-topic" data-topic-id={{@topic.id}}>
    <dl class="context-topic__stats">
      <div>
        <dt>{{i18n "replies"}}</dt>
        <dd>{{dNumber @topic.replyCount}}</dd>
      </div>
      <div>
        <dt>{{i18n "views"}}</dt>
        <dd>{{dNumber @topic.views}}</dd>
      </div>
      <div>
        <dt>{{i18n "likes"}}</dt>
        <dd>{{dNumber @topic.like_count}}</dd>
      </div>
    </dl>

    <PluginOutlet
      @defaultGlimmer={{true}}
      @name="topic-context-summary"
      @outletArgs={{lazyHash topic=@topic postStream=@topic.postStream}}
    />

    {{#if @topic.details.participants.length}}
      <TopicParticipants
        @participants={{@topic.details.participants}}
        @title={{i18n "topic_map.participants_title"}}
      />
    {{/if}}

    {{#if @topic.details.links.length}}
      <h3>{{i18n "topic_map.links_title"}}</h3>
      <ul class="context-topic__links">
        {{#each @topic.details.links as |link|}}
          <li>
            <TopicMapLink
              @attachment={{link.attachment}}
              @clickCount={{link.clicks}}
              @rootDomain={{link.root_domain}}
              @title={{link.title}}
              @url={{link.url}}
              @userId={{link.user_id}}
            />
          </li>
        {{/each}}
      </ul>
    {{/if}}
  </div>
</template>;

export default class ContextTopic extends Component {
  @service header;

  <template>
    {{#each (array this.header.topicInfo) key="id" as |topic|}}
      <TopicDetails @topic={{topic}} />
    {{/each}}
  </template>
}
