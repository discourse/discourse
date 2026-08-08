import BreadCrumbs from "discourse/components/bread-crumbs";
import CreateTopicButton from "discourse/components/create-topic-button";
import NavigationBar from "discourse/components/navigation-bar";
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";

export default <template>
  <div class="list-controls">
    <div class="container">
      <section class="navigation-container">
        <BreadCrumbs @categories={{@categories}} />
        <NavigationBar @navItems={{@navItems}} @filterMode="latest" />

        <div class="navigation-controls">
          <CategoriesAdminDropdown />
          <CreateTopicButton @canCreateTopic={{true}} />
        </div>
      </section>
    </div>
  </div>
</template>
