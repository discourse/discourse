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
        self.set("categories", items);
      },
      template: Discourse.CategoryGroupComponent.templateFunction(),
      transformComplete: function(category){
        return Discourse.HTML.categoryLink(category);
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
                                          "{{categoryLinkRaw this}}" +
                                      "</li>" +
                                      "{{/each}}" +
                                    "</ul>" +
                                  "</div>");
      return this.compiled;
    }
});
