/**
  Return the count of users at the given trust level.

  @method valueAtTrustLevel
  @for Handlebars
**/
Handlebars.registerHelper('valueAtTrustLevel', function(property, trustLevel) {
  var data = Ember.Handlebars.get(this, property);
  if( data ) {
    var item = data.find( function(d, i, arr) { return parseInt(d.x,10) === parseInt(trustLevel,10); } );
    if( item ) {
      return item.y;
    } else {
      return 0;
    }
  }
});