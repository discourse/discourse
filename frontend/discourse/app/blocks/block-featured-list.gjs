import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { i18n } from "discourse-i18n";

@block("featured-list")
export default class BlockFeaturedList extends Component {
  @service store;
  @service currentUser;

  @tracked filteredTopics = null;

  <template>
    <div class="block-featured-list__container">
      <div class="block-featured-list__layout">
        {{#if this.filteredTopics}}
          <div class="block-featured-list__header">
            {{#if @title}}
              <h2 class="block-featured-list__title">
                {{@title}}
              </h2>
            {{/if}}
            {{#if @link}}
              <a
                href={{@link}}
                class="block-featured-list__link"
                style="..."
              >{{i18n "js.more"}}</a>
            {{/if}}
          </div>
          <ConditionalLoadingSpinner @condition={{this.isLoading}}>
            <BasicTopicList
              @topics={{this.filteredTopics}}
              @showPosters="true"
              class="block-featured-list__topic-list"
            />
          </ConditionalLoadingSpinner>
        {{/if}}
      </div>
    </div>
  </template>

  constructor() {
    super(...arguments);
    this.findFilteredTopics();
  }

  @action
  async findFilteredTopics() {
    const count = this.args.count || 5;
    const filter = this.args.filter || "latest";
    const category = this.args.id;
    const tags = this.args.tag;
    const solved = this.args.solved;

    const userFilters = ["new", "unread"];
    if (userFilters.includes(`${filter}`) && !this.currentUser) {
      return;
    }
    const topicList = await this.store.findFiltered("topicList", {
      filter,
      params: {
        category,
        tags,
        solved,
      },
    });
    if (topicList.topics) {
      return (this.filteredTopics = topicList.topics.slice(0, count));
    }
  }
}
