import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { block } from "discourse/blocks";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import dIcon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";

@block("featured-topics")
export default class BlockFeaturedTopics extends Component {
  @tracked featuredTopics = null;

  constructor() {
    super(...arguments);

    if (!this.args?.tag) {
      return;
    }

    const count = this.args?.count || 5;
    const featuredTopicsUrl = "/tag/" + this.args.tag + ".json";

    this.blockClass = this.args?.class;
    this.blockTitle = this.args?.title;
    this.blockTitleIcon = this.args?.icon;

    ajax(featuredTopicsUrl).then((data) => {
      let results = [];
      results = data.topic_list.topics;

      if (this.args?.shuffle === "true") {
        results = this.shuffle(results);
      }
      this.featuredTopics = results.slice(0, count);

      this.featuredTopics.forEach((topic) => {
        topic["category"] = Category.findById(topic.category_id);

        if (topic.posters) {
          topic.creator = (data.users || []).find(
            (user) => user.id === topic.posters[0].user_id
          );
        }
      });
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.featuredTopics = null;
  }

  shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
  }

  <template>
    <div class="block-featured-topics__container">
      {{#if this.blockTitle}}
        <h2 class="block-featured-topics__title">
          {{#if this.blockTitleIcon}}
            {{dIcon this.blockTitleIcon}}
          {{/if}}
          {{this.blockTitle}}
        </h2>
      {{/if}}

      <div class="block-featured-topics__list">
        {{#each this.featuredTopics as |topic|}}

          <a
            class="block-featured-topics__topic-container"
            href="/t/{{topic.slug}}/{{topic.id}}/{{topic.last_read_post_number}}"
          >
            {{#if topic.image_url}}
              <div
                class="block-featured-topics__topic-image"
                style={{htmlSafe
                  (concat "background-image: url(" topic.image_url ")")
                }}
              ></div>
            {{/if}}

            <div class="block-featured-topics__topic-details">
              <div class="category-link">
                {{categoryLinkHTML topic.category}}
              </div>
              <span class="topic-date">{{formatDate
                  topic.last_posted_at
                  format="tiny"
                }}</span>
              <h3 class="topic-title">{{htmlSafe topic.title}}</h3>

              {{#if topic.excerpt}}
                {{#if topic.image_url}}
                  <div class="topic-excerpt has-image">
                    {{htmlSafe topic.excerpt}}
                  </div>
                {{else}}
                  <div class="topic-excerpt">
                    {{htmlSafe topic.excerpt}}
                  </div>
                {{/if}}

              {{/if}}
              <div class="topic-author">
                <UserLink @user={{topic.creator}}>
                  {{avatar topic.creator imageSize="medium"}}
                  <span class="topic-author-name">{{topic.creator.name}}</span>
                </UserLink>

              </div>
            </div>
          </a>

        {{/each}}
      </div>
    </div>
  </template>
}
