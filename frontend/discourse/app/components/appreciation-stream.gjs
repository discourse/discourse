import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import AppreciationAction from "discourse/components/appreciation-action";
import PostList from "discourse/components/post-list";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { ajax } from "discourse/lib/ajax";
import {
  flattenAppreciation,
  groupAppreciations,
  PAGE_SIZE,
} from "discourse/lib/appreciation-stream";
import { addUniqueValuesToArray } from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";

export default class AppreciationStream extends Component {
  @tracked canLoadMore = this.args.canLoadMore ?? true;
  @tracked loading = false;
  @tracked _lastCursor = null;

  get lastCursor() {
    return this._lastCursor ?? this.args.lastCursor;
  }

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loading) {
      return [];
    }

    this.loading = true;

    try {
      const data = {};
      if (this.lastCursor) {
        data.before = this.lastCursor;
      }
      if (this.args.types) {
        data.types = this.args.types;
      }

      const result = await ajax(
        `/u/${this.args.username}/appreciations/${this.args.direction}.json`,
        { data }
      );

      const appreciations = result.appreciations || [];
      const flat = appreciations.map(flattenAppreciation);

      if (flat.length > 0) {
        this._lastCursor = flat[flat.length - 1].created_at;
      }

      const grouped = groupAppreciations(flat);
      addUniqueValuesToArray(this.args.items, grouped);

      if (flat.length < PAGE_SIZE) {
        this.canLoadMore = false;
      }

      return grouped;
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#if this.canLoadMore}}
      {{hideApplicationFooter}}
    {{/if}}
    <PostList
      @posts={{@items}}
      @fetchMorePosts={{this.loadMore}}
      @emptyText={{i18n "user_activity.no_activity_title"}}
      @additionalItemClasses="user-stream-item"
      @titlePath="titleHtml"
      @showUserInfo={{false}}
      class="user-stream appreciation-stream"
    >
      <:abovePostItemExcerpt as |item|>
        <AppreciationAction @item={{item}} />
      </:abovePostItemExcerpt>
    </PostList>
  </template>
}
