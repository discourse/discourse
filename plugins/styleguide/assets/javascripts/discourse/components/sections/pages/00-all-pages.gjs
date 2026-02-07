import Component from "@glimmer/component";
import { service } from "@ember/service";
import BreadCrumbs from "discourse/components/bread-crumbs";
import CategoriesOnly from "discourse/components/categories-only";
import CreateTopicButton from "discourse/components/create-topic-button";
import NavigationBar from "discourse/components/navigation-bar";
import Post from "discourse/components/post";
import TopicCategory from "discourse/components/topic-category";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";
import TopicList from "discourse/components/topic-list/list";
import TopicStatus from "discourse/components/topic-status";
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class AllPages extends Component {
  @service site;

  <template>
    <StyleguideExample @title="topic list page">
      <div class="list-controls">
        <div class="container">
          <section class="navigation-container">
            <BreadCrumbs @categories={{@dummy.categories}} />
            <NavigationBar @navItems={{@dummy.navItems}} @filterMode="latest" />
            <div class="navigation-controls">
              <CategoriesAdminDropdown />
              <CreateTopicButton
                @canCreateTopic={{true}}
                @action={{@createTopic}}
              />
            </div>
          </section>
        </div>
      </div>
      <TopicList @topics={{@dummy.topics}} @showPosters={{true}} />
    </StyleguideExample>

    <StyleguideExample @title="topic page">
      <div id="topic-title" class="container">
        <div class="title-wrapper">
          <h1>
            <TopicStatus @topic={{@dummy.topic}} />
            <a class="fancy-title">
              {{@dummy.topic.fancyTitle}}
            </a>
          </h1>
          <TopicCategory @topic={{@dummy.topic}} class="topic-category" />
        </div>
      </div>
      {{#each @dummy.topicPagePosts as |postData|}}
        <Post @post={{postData}} @canCreatePost={{true}} />
      {{/each}}
      <TopicFooterButtons
        @topic={{@dummy.topic}}
        @replyToPost={{@replyToPost}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<CategoriesOnly>"
      @code={{this.categoriesOnlyCode}}
    >
      <CategoriesOnly @categories={{this.site.categories}} />
    </StyleguideExample>
  </template>
}
