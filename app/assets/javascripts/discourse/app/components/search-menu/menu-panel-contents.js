import Component from "@glimmer/component";

export default class MenuPanelContents extends Component {
  constructor() {
    super(...arguments);

    //if (searchData.loading) {
    //searchInput.push(h("div.searching", h("div.spinner")));
    //} else {
    //const clearButton = this.attach("link", {
    //title: "search.clear_search",
    //action: "clearSearch",
    //className: "clear-search",
    //contents: () => iconNode("times"),
    //});

    //const advancedSearchButton = this.attach("link", {
    //href: this.fullSearchUrl({ expanded: true }),
    //contents: () => iconNode("sliders-h"),
    //className: "show-advanced-search",
    //title: "search.open_advanced",
    //});

    //if (searchData.term) {
    //searchInput.push(
    //h("div.searching", [clearButton, advancedSearchButton])
    //);
    //} else {
    //searchInput.push(h("div.searching", advancedSearchButton));
    //}
    //}

    //const results = [h("div.search-input", searchInput)];

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
}
