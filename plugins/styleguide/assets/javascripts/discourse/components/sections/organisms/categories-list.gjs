import Component from "@glimmer/component";
import CategoriesOnly from "discourse/components/categories-only";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class CategoriesList extends Component {
  get categoriesOnlyCode() {
    return `
import CategoriesOnly from "discourse/components/categories-only";

<template>
  <CategoriesOnly @categories={{@dummy.categories}} />
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<CategoriesOnly>"
      @code={{this.categoriesOnlyCode}}
    >
      <CategoriesOnly @categories={{@dummy.categories}} />
    </StyleguideExample>
  </template>
}
