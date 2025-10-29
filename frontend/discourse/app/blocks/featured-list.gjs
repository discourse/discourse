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
import { i18n } from "discourse-i18n";

@block("featured-list")
export default class BlockFeaturedList extends Component {
  @service store;
  @service router;
  @service composer;
  @service currentUser;

  @tracked filteredTopics = null;

  <template>
    {{#if this.filteredTopics}}
      <div class="block-featured-list {{this.blockClass}}">
        <div class="block-featured-list__container">
          <div class="block-featured-list__header">
            <h2 class="block-featured-list__title">
              {{#if this.blockTitleIcon}}
                {{dIcon this.blockTitleIcon}}
              {{/if}}
              {{this.blockTitle}}
            </h2>
            {{#if this.blockLink}}
              <a href="{{this.blockLink}}" class="feed-link" style="...">{{i18n
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
        </div>
      </div>
    {{/if}}
  </template>

  constructor() {
    super(...arguments);
    this.blockTitle = this.args?.params?.title || "Featured List";
    this.blockTitleIcon = this.args?.params?.icon;
    this.blockClass = this.args?.params?.class;
    this.blockLink = this.args?.params?.link;

    this.findFilteredTopics();
  }

  @action
  async findFilteredTopics() {
    const count = this.args?.params?.count || 5;
    const filter = this.args?.params?.filter || "latest";
    const category = this.args?.params?.id;
    const tags = this.args?.params?.tag;
    const solved = this.args?.params?.solved;

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
      category: Category.findById(this.args?.params?.id),
      tags: this.args?.params?.tag,
      preferDraft: "true",
    });
  }

  @action
  showLogin() {
    this.router.replaceWith("login");
  }

  get title() {}
}
