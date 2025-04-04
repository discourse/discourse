import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import BreadCrumbs from "discourse/components/bread-crumbs";
import NavigationBar from "discourse/components/navigation-bar";
import CategoriesAdminDropdown from "select-kit/components/categories-admin-dropdown";
import CreateTopicButton from "discourse/components/create-topic-button";
const Navigation = <template><StyleguideExample @title="navigation">
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
</StyleguideExample></template>;
export default Navigation;