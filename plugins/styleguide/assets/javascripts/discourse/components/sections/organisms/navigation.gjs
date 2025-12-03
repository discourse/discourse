import Component from "@glimmer/component";
import BreadCrumbs from "discourse/components/bread-crumbs";
import CreateTopicButton from "discourse/components/create-topic-button";
import NavigationBar from "discourse/components/navigation-bar";
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Navigation extends Component {
  get navigationCode() {
    return `
import BreadCrumbs from "discourse/components/bread-crumbs";
import CreateTopicButton from "discourse/components/create-topic-button";
import NavigationBar from "discourse/components/navigation-bar";
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";

<template>
  <div class="list-controls">
    <div class="container">
      <section class="navigation-container">
        <BreadCrumbs @categories={{@dummy.categories}} />
        <NavigationBar @navItems={{@dummy.navItems}} @filterMode="latest" />

        <div class="navigation-controls">
          <CategoriesAdminDropdown />
          <CreateTopicButton @canCreateTopic={{true}} />
        </div>
      </section>
    </div>
  </div>
</template>
    `;
  }

  <template>
    <StyleguideExample @title="navigation" @code={{this.navigationCode}}>
      <div class="list-controls">
        <div class="container">
          <section class="navigation-container">
            <BreadCrumbs @categories={{@dummy.categories}} />
            <NavigationBar @navItems={{@dummy.navItems}} @filterMode="latest" />

            <div class="navigation-controls">
              <CategoriesAdminDropdown />
              <CreateTopicButton @canCreateTopic={{true}} />
            </div>
          </section>
        </div>
      </div>
    </StyleguideExample>
  </template>
}
