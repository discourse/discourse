var controller, oldSearchTextField, oldSearchResultsTypeView;

var SearchTextFieldStub = Ember.View.extend({
  classNames: ["search-text-field-stub"],
  template: Ember.Handlebars.compile("{{view.value}} {{view.searchContext}}")
});

var SearchResultsTypeViewStub = Ember.View.extend({
  classNames: ["search-results-type-view-stub"],
  template: Ember.Handlebars.compile("{{view.type}} {{view.content}}")
});

var setUpController = function(properties) {
  Ember.run(function() {
    controller.setProperties(properties);
  });
};

var appendView = function() {
  Ember.run(function() {
    Discourse.advanceReadiness();
    Ember.View.create({
      container: Discourse.__container__,
      controller: controller,
      templateName: "search"
    }).appendTo(fixture());
  });
};

var resultsSectionSelector = "ul";
var resultsFilterSelector = ".filter";
var noResultsSelector = ".no-results";
var searchInProgressSelector = ".searching";

module("Template: search", {
  setup: function() {
    sinon.stub(I18n, "t").returnsArg(0);

    oldSearchTextField = Discourse.SearchTextField;
    Discourse.SearchTextField = SearchTextFieldStub;

    oldSearchResultsTypeView = Discourse.SearchResultsTypeView;
    Discourse.SearchResultsTypeView = SearchResultsTypeViewStub;

    controller = Ember.ArrayController.create();
  },

  teardown: function() {
    I18n.t.restore();

    Discourse.SearchTextField = oldSearchTextField;
    Discourse.SearchResultsTypeView = oldSearchResultsTypeView;
  }
});

test("contain search text field (correctly bound to contextual placeholder and search term values)", function() {
  setUpController({
    term: "term",
    searchContext: "searchContext"
  });

  appendView();

  var $searchTextField = fixture(".search-text-field-stub");
  ok(exists($searchTextField), "the field exists");
  equal($searchTextField.text(), "term searchContext", "the placeholder and search term values are correctly bound");
});

test("shows spinner icon instead of results area when loading", function() {
  setUpController({
    loading: true
  });

  appendView();

  ok(exists(fixture(".search-text-field-stub")), "the search field is still shown, even when loading results");

  ok(!exists(fixture(resultsSectionSelector)), "no results are shown");
  ok(!exists(fixture(noResultsSelector)), "the 'no results' message is not shown");

  var $searchInProgress = fixture(searchInProgressSelector);
  ok(exists($searchInProgress), "the 'search in progress' message is shown");
  ok(exists($searchInProgress.find(".fa-spinner")), "the 'search in progress' message contains a spinner icon");
});

test("shows 'no results' message when loading has finished and there are no results found", function() {
  setUpController({
    loading: false,
    noResults: true
  });

  appendView();

  ok(exists(fixture(".search-text-field-stub")), "the search field is shown to allow another search");

  ok(!exists(fixture(resultsSectionSelector)), "no results are shown");
  ok(!exists(fixture(searchInProgressSelector)), "the 'search in progress' message is not shown");

  var $noResults = fixture(noResultsSelector);
  ok(exists($noResults), "the 'no results' message is shown");
  notEqual($noResults.text().indexOf("search.no_results"), -1, "the 'no results' message contains correct text");
});

test("shows only search text field when user starts typing a new search term, but there are not enough characters typed yet", function() {
  setUpController({
    loading: false,
    noResults: false,
    content: []
  });

  appendView();

  ok(exists(fixture(".search-text-field-stub")), "search text field is shown");

  ok(!exists(fixture(resultsSectionSelector)), "no results are shown");
  ok(!exists(fixture(searchInProgressSelector)), "the 'search in progress' message is not shown");
  ok(!exists(fixture(noResultsSelector)), "the 'no results' message is not shown");
});

test("correctly iterates through and displays search results when the search succeeds", function() {
  setUpController({
    loading: false,
    noResults: false,
    content: [
      Ember.Object.create({
        more: true,
        name: "name_1",
        results: "results_1",
        type: "type_1"
      }),
      Ember.Object.create({
        more: false,
        name: "name_2",
        results: "results_2",
        type: "type_2"
      })
    ]
  });

  appendView();

  var $resultSections = fixture(resultsSectionSelector);

  equal(count($resultSections), 2, "the number of sections in results is correct");

  var $firstSection = $resultSections.eq(0);
  var $filter = $firstSection.find(resultsFilterSelector);
  notEqual($firstSection.text().indexOf("name_1"), -1, "the name of the first section is correct");
  ok(exists($filter), "the 'show more' link in the first section exists");
  notEqual($filter.text().indexOf("show_more"), -1, "the 'show more' link in the first section contains correct text");
  equal($firstSection.find(".search-results-type-view-stub").text(), "type_1 results_1", "the results view in the first section is correctly rendered");

  var $secondSection = $resultSections.eq(1);
  notEqual($secondSection.text().indexOf("name_2"), -1, "the name of the second section is correct");
  ok(!exists($secondSection.find(resultsFilterSelector)), "the 'show more' link in the second section does not exist");
  equal($secondSection.find(".search-results-type-view-stub").text(), "type_2 results_2", "the results view in the second section is correctly rendered");
});

test("displays 'close more results' button when the search is in the more results mode", function() {
  setUpController({
    loading: false,
    noResults: false,
    showCancelFilter: true,
    content: [
      Ember.Object.create({
        more: false
      })
    ]
  });

  appendView();

  var $firstSection = fixture(resultsSectionSelector).eq(0);
  var $filter = $firstSection.find(resultsFilterSelector);
  ok(exists($filter), "the 'close more results' button exists");
  ok(exists($filter.find(".fa-times-circle")), "the 'close more results' contains correct icon");
});
