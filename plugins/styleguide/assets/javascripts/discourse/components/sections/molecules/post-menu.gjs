import Component from "@glimmer/component";
import PostMenu from "discourse/components/post/menu";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class CharCounterMolecule extends Component {
  get sampleCode() {
    return `
import PostMenu from "discourse/components/post/menu";

<template>
  <PostMenu
    @post={{@dummy.transformedPost}}
    @canCreatePost={{true}}
    @showFlags={{true}}
    @showLogin={{true}}
    @showReadIndicator={{true}}
    @toggleLike={{true}}
  />
</template>
    `;
  }

  <template>
    <StyleguideExample @title="<PostMenu>" @code={{this.sampleCode}}>
      <PostMenu
        @post={{@dummy.transformedPost}}
        @canCreatePost={{true}}
        @showFlags={{true}}
        @showLogin={{true}}
        @showReadIndicator={{true}}
        @toggleLike={{true}}
      />
    </StyleguideExample>
  </template>
}
