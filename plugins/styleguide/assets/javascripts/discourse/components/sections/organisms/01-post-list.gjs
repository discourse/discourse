import Component from "@glimmer/component";
import PostList from "discourse/components/post-list";
import { i18n } from "discourse-i18n";
import StyleguideExample from "../../styleguide-example";

export default class StyleguidePostList extends Component {
  get emptyPostListCode() {
    return `
import PostList from "discourse/components/post-list";

<template>
  <PostList @posts="" @additionalItemClasses="styleguide-post-list-item" />
</template>
    `;
  }

  get populatedPostListCode() {
    return `
import PostList from "discourse/components/post-list";

<template>
  <PostList
    @posts={{@dummy.postList}}
    @additionalItemClasses="styleguide-post-list-item"
  />
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title={{i18n "styleguide.sections.post_list.empty_example"}}
      @code={{this.emptyPostListCode}}
    >
      <PostList @posts="" @additionalItemClasses="styleguide-post-list-item" />
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.post_list.populated_example"}}
      @code={{this.populatedPostListCode}}
    >
      <PostList
        @posts={{@dummy.postList}}
        @additionalItemClasses="styleguide-post-list-item"
      />
    </StyleguideExample>
  </template>
}
