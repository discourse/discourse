import Component from "@glimmer/component";
import BreadCrumbs from "discourse/components/bread-crumbs";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class BreadCrumbsMolecule extends Component {
  get categoryBreadcrumbsCode() {
    return `
import BreadCrumbs from "discourse/components/bread-crumbs";

<template>
  <BreadCrumbs @categories={{@dummy.categories}} @showTags={{false}} />
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<BreadCrumbs>"
      @code={{this.categoryBreadcrumbsCode}}
    >
      <BreadCrumbs @categories={{@dummy.categories}} @showTags={{false}} />
    </StyleguideExample>
  </template>
}
