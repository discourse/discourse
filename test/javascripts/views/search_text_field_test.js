var view;

var placeholderUsesKeyAndContext = function(key, context) {
  var placeholder = view.get("placeholder");
  equal(placeholder.key, key, "placeholder contains correct message");
  deepEqual(placeholder.context, context, "correct parameters are passed to the message");
};

module("Discourse.SearchTextField", {
  setup: function() {
    sinon.stub(I18n, "t", function(key, context) {
      return {key: key, context: context};
    });

    view = Discourse.SearchTextField.create();
  },

  teardown: function() {
    I18n.t.restore();
  }
});

test("formats placeholder correctly when no searchContext is provided", function() {
  placeholderUsesKeyAndContext("search.placeholder", undefined);
});

test("formats placeholder correctly when user searchContext is provided", function() {
  view.set("searchContext", {
    type: "user",
    user: {
      username: "userName"
    }
  });
  placeholderUsesKeyAndContext("search.prefer.user", {username: "userName"});
});

test("formats placeholder correctly when category searchContext is provided", function() {
  view.set("searchContext", {
    type: "category",
    category: {
      name: "categoryName"
    }
  });
  placeholderUsesKeyAndContext("search.prefer.category", {category: "categoryName"});
});
