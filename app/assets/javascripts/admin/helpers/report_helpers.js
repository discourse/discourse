/**
  Get the y value of a report data point by its index. Negative indexes start from the end.

  @method reportValueY
  @for Handlebars
**/
Handlebars.registerHelper('valueAtDaysAgo', function(property, i) {
  var data = Ember.Handlebars.get(this, property);
  if( data ) {
    var wantedDate = Date.create(i + ' days ago').format('{yyyy}-{MM}-{dd}');
    var item = data.find( function(d, i, arr) { return d.x == wantedDate; } );
    if( item ) {
      return item.y;
    } else {
      return 0;
    }
  }
});

/**
  Sum the given number of data points from the report, starting at the most recent.

  @method sumLast
  @for Handlebars
**/
Handlebars.registerHelper('sumLast', function(property, numDays) {
  var data = Ember.Handlebars.get(this, property);
  if( data ) {
    var earliestDate = Date.create(numDays + ' days ago');
    var sum = 0;
    data.each(function(d){
      if(Date.create(d.x) >= earliestDate) {
        sum += d.y;
      }
    });
    return sum;
  }
});
