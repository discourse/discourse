import Component from "@glimmer/component";
import { service } from "@ember/service";
import CategoriesOnly from "discourse/components/categories-only";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class CategoriesList extends Component {
  @service site;

  get categoriesOnlyCode() {
    return `import CategoriesOnly from "discourse/components/categories-only";
import { service } from "@ember/service";
export default class CategoriesOnlyExample extends Component {
  @service site;

<template>
  <CategoriesOnly @categories={{this.site.categories}} />
</template>
}`;
  }

  <template>
    <StyleguideExample
      @title="<CategoriesOnly>"
      @code={{this.categoriesOnlyCode}}
    >
      <CategoriesOnly @categories={{this.site.categories}} />
    </StyleguideExample>
  </template>
}
