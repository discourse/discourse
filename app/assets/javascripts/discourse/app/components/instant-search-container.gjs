import Component from "@glimmer/component";
import AisInstantSearch from "@discourse/ember-instantsearch";

// Test component to test importing components from @discourse/ember-instantsearch v2 addon
export default class InstantSearchContainer extends Component {
  get apiData() {
    return {
      apiKey: "xyz",
      port: 8108,
      host: "typesense.demo-by-discourse.com",
      protocol: "https",
      indexName: "posts",
      queryBy: "topic_title,cooked,author_username",
    };
  }

  <template>
    <h1>Hello World!</h1>
    <AisInstantSearch
      @apiData={{this.apiData}}
      @middleware={{this.customMiddleware}}
      @configurationOptions={{this.configurationOptions}}
      as |Ais|
    >
      Stuff
    </AisInstantSearch>
  </template>
}
