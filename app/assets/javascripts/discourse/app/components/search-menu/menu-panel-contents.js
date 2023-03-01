import Component from "@glimmer/component";

export default class MenuPanelContents extends Component {
  constructor() {
    super(...arguments);

    //if (
    //this.state.inTopicContext &&
    //(!SearchHelper.includesTopics() || !searchData.term)
    //) {
    //const isMobileDevice = this.site.isMobileDevice;

    //if (!isMobileDevice) {
    //results.push(this.attach("browser-search-tip"));
    //}
    //return results;
    //}

    //if (!searchData.loading) {
    //results.push(
    //this.attach("search-menu-results", {
    //term: searchData.term,
    //noResults: searchData.noResults,
    //results: searchData.results,
    //invalidTerm: searchData.invalidTerm,
    //suggestionKeyword: searchData.suggestionKeyword,
    //suggestionResults: searchData.suggestionResults,
    //searchTopics: SearchHelper.includesTopics(),
    //inPMInboxContext: this.state.inPMInboxContext,
    //})
    //);
    //}

    //return results;
  }

  get advancedSearchButtonHref() {
    return this.args.fullSearchUrl({ expanded: true });
  }
}
