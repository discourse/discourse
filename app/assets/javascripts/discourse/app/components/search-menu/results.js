import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CategoryViewComponent from "./results/type/category";
import GroupViewComponent from "./results/type/group";
import PostViewComponent from "./results/type/post";
import TagViewComponent from "./results/type/tag";
import TopicViewComponent from "./results/type/topic";
import UserViewComponent from "./results/type/user";

const SEARCH_RESULTS_COMPONENT_TYPE = {
  "search-result-category": CategoryViewComponent,
  "search-result-topic": TopicViewComponent,
  "search-result-post": PostViewComponent,
  "search-result-user": UserViewComponent,
  "search-result-tag": TagViewComponent,
  "search-result-group": GroupViewComponent,
};

export default class Results extends Component {
  @service search;
  @service site;

  // TODO: unused local prop `searchTopics`
  @tracked searchTopics = this.args.searchTopics;

  get isMobileTopicView() {
    return (
      this.site.isMobileViewAndDevice && this.search.contextType === "topic"
    );
  }

  get renderInitialOptions() {
    return (
      !this.search.activeGlobalSearchTerm &&
      !this.args.inPMInboxContext &&
      (!this.site.isMobileViewAndDevice || this.isMobileTopicView)
    );
  }

  get noTopicResults() {
    return this.args.searchTopics && this.search.noResults;
  }

  get termTooShort() {
    return this.args.searchTopics && this.args.invalidTerm;
  }

  get resultTypesWithComponent() {
    let content = [];
    this.search.results.resultTypes?.map((resultType) => {
      content.push({
        ...resultType,
        component: SEARCH_RESULTS_COMPONENT_TYPE[resultType.componentName],
      });
    });
    return content;
  }

  get searchLogId() {
    return this.search.results.grouped_search_result?.search_log_id;
  }

  // TODO: unused action `updateSearchTopics`
  @action
  updateSearchTopics(value) {
    this.searchTopics = value;
  }
}
