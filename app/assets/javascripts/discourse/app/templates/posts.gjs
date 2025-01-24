import Component from "@glimmer/component";
import { action } from "@ember/object";
import RouteTemplate from "ember-route-template";
import PostList from "discourse/components/post-list";
import Posts from "discourse/models/posts";

export default RouteTemplate(
  class extends Component {
    @action
    async loadMorePosts() {
      const posts = this.args.model;
      const before = posts[posts.length - 1].created_at;

      return Posts.find({ before });
    }

    <template>
      <PostList
        @posts={{@model}}
        @fetchMorePosts={{this.loadMorePosts}}
        @titlePath="topic_html_title"
      />
    </template>
  }
);
