import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import PostList from "discourse/components/post-list";
import avatar from "discourse/helpers/avatar";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { ajax } from "discourse/lib/ajax";
import { addUniqueValuesToArray } from "discourse/lib/array-tools";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import { flattenBoost, PAGE_SIZE } from "../lib/boosts-stream";

export default class BoostsStream extends Component {
  @tracked canLoadMore = this.args.canLoadMore ?? true;
  @tracked loading = false;

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loading) {
      return [];
    }

    this.loading = true;

    try {
      const lastBoost = this.args.boosts[this.args.boosts.length - 1];
      const beforeBoostId = lastBoost?.boost_id;

      const result = await ajax(
        `/discourse-boosts/users/${this.args.username}/${this.args.boostsUrl}.json`,
        { data: { before_boost_id: beforeBoostId } }
      );

      const boosts = result.boosts || [];
      const flattened = boosts.map(flattenBoost);

      addUniqueValuesToArray(this.args.boosts, flattened);

      if (flattened.length < PAGE_SIZE) {
        this.canLoadMore = false;
      }

      return flattened;
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#if this.canLoadMore}}
      {{hideApplicationFooter}}
    {{/if}}
    <PostList
      @posts={{@boosts}}
      @fetchMorePosts={{this.loadMore}}
      @emptyText={{i18n "notifications.empty"}}
      @additionalItemClasses="user-stream-item"
      @titlePath="titleHtml"
      @showUserInfo={{false}}
      class="user-stream"
    >
      <:abovePostItemExcerpt as |boost|>
        <div class="discourse-boosts-activity__boost">
          <a
            href={{userPath boost.booster.username}}
            data-user-card={{boost.booster.username}}
            class="discourse-boosts-activity__avatar"
          >
            {{avatar boost.booster imageSize="tiny"}}
          </a>
          <span class="discourse-boosts-activity__cooked">{{trustHTML
              boost.boost_cooked
            }}</span>
        </div>
      </:abovePostItemExcerpt>
    </PostList>
  </template>
}
