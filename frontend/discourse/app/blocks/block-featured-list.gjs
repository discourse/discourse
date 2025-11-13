import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import dIcon from "discourse/helpers/d-icon";
import Category from "discourse/models/category";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

@block("featured-list")
export default class BlockFeaturedList extends Component {
  @service store;
  @service router;
  @service composer;
  @service currentUser;

  @tracked filteredTopics = null;

  <template>
    <div class="block-featured-list__container">
      <div class="block-featured-list__layout">
        {{#if this.filteredTopics}}
          <div class="block-featured-list__header">
            <h2 class="block-featured-list__title">
              {{#if @icon}}
                {{dIcon @icon}}
              {{/if}}
              {{or @title "Featured List"}}
            </h2>
            {{#if @link}}
              <a href={{@link}} class="feed-link" style="...">{{i18n
                  "more_link"
                }}</a>
            {{/if}}
            <DButton
              class="btn btn-default"
              {{on
                "click"
                (if this.currentUser this.createTopic this.showLogin)
              }}
            >{{i18n "post_button"}}</DButton>
          </div>
          <ConditionalLoadingSpinner @condition={{this.isLoading}}>
            <BasicTopicList
              @topics={{this.filteredTopics}}
              @showPosters="true"
              class="block-featured-list__list-body"
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

  @action
  createTopic() {
    this.composer.openNewTopic({
      category: Category.findById(this.args.id),
      tags: this.args.tag,
      preferDraft: "true",
    });
  }

  @action
  showLogin() {
    this.router.replaceWith("login");
  }
}
