Discourse.CategoryGroupComponent = Ember.Component.extend({

  didInsertElement: function(){
    var self = this;

    this.$('input').autocomplete({
      items: this.get('categories'),
      single: false,
      allowAny: false,
      dataSource: function(term){
        return Discourse.Category.list().filter(function(category){
          var regex = new RegExp(term, "i");
          return category.get("name").match(regex) &&
            !_.contains(self.get('categories'), category);
        });
      },
      onChangeItems: function(items) {
        var categories = _.map(items, function(link) {
          var slug = link.match(/href=['"]\/category\/([^'"]+)/)[1];
          return Discourse.Category.findSingleBySlug(slug);
        });
        self.set("categories", categories);
      },
      template: Discourse.CategoryGroupComponent.templateFunction(),
      transformComplete: function(category) {
        return Discourse.HTML.categoryBadge(category, {allowUncategorized: true});
      }
    });
  }

});

Discourse.CategoryGroupComponent.reopenClass({
  templateFunction: function(){
      this.compiled = this.compiled || Handlebars.compile("<div class='autocomplete'>" +
                                    "<ul>" +
                                    "{{#each options}}" +
                                      "<li>" +
                                          "{{categoryLinkRaw this allowUncategorized=true}}" +
                                      "</li>" +
                                      "{{/each}}" +
                                    "</ul>" +
                                  "</div>");
      return this.compiled;
    }
});
