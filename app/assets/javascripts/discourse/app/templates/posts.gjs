import Component from "@glimmer/component";
import { action } from "@ember/object";
import RouteTemplate from "ember-route-template";
import PostList from "discourse/components/post-list";
import Posts from "discourse/models/posts";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  class extends Component {
    @action
    async loadMorePosts() {
      const posts = this.args.model;
      const before = posts[posts.length - 1].id;

      return Posts.find({ before });
    }

    <template>
      <section class="posts-page">
        <h2 class="posts-page__title">{{i18n "post_list.title"}}</h2>
        <PostList
          @posts={{@model}}
          @fetchMorePosts={{this.loadMorePosts}}
          @titlePath="topic_html_title"
        />
      </section>
    </template>
  }
);
