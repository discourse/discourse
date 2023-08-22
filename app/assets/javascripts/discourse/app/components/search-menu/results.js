import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import TopicViewComponent from "./results/type/topic";
import PostViewComponent from "./results/type/post";
import UserViewComponent from "./results/type/user";
import TagViewComponent from "./results/type/tag";
import GroupViewComponent from "./results/type/group";
import CategoryViewComponent from "./results/type/category";

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

  @tracked searchTopics = this.args.searchTopics;

  get renderInitialOptions() {
    return !this.search.activeGlobalSearchTerm && !this.args.inPMInboxContext;
  }

  get noTopicResults() {
    return this.args.searchTopics && this.args.noResults;
  }

  get termTooShort() {
    return this.args.searchTopics && this.args.invalidTerm;
  }

  get resultTypesWithComponent() {
    let content = [];
    this.args.results.resultTypes?.map((resultType) => {
      content.push({
        ...resultType,
        component: SEARCH_RESULTS_COMPONENT_TYPE[resultType.componentName],
      });
    });
    return content;
  }

  @action
  updateSearchTopics(value) {
    this.searchTopics = value;
  }
}
