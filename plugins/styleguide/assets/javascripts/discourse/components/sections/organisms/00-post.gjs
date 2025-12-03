import Component from "@glimmer/component";
import Post from "discourse/components/post";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class PostOrganism extends Component {
  get postCode() {
    return `import Post from "discourse/components/post";

<template>
  <Post @post={{@dummy.postModel}} />
</template>`;
  }

  <template>
    <StyleguideExample @title="<Post>" @code={{this.postCode}}>
      <Post @post={{@dummy.postModel.transformedPost}} />
    </StyleguideExample>
  </template>
}
