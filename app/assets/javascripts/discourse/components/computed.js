Discourse.computed = {

  /**
    Returns whether two properties are equal to each other.

    @method propertyEqual
    @params {String} p1 the first property
    @params {String} p2 the second property
    @return {Function} computedProperty function
  **/
  propertyEqual: function(p1, p2) {
    return Ember.computed(function() {
      return this.get(p1) === this.get(p2);
    }).property(p1, p2);
  }

};
