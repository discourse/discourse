Discourse.Formatter = (function(){
  var updateRelativeAge, autoUpdatingRelativeAge, relativeAge;

  updateRelativeAge = function(elems) {
    elems.each(function(){
      var $this = $(this);
      $this.html(relativeAge(new Date($this.data('time')), $this.data('format')));
    });
  };

  autoUpdatingRelativeAge = function(date,options) {
    options = options || {};
    var format = options.format || "tiny";

    return "<span class='relative-date' data-time='" + date.getTime() + "' data-format='" + format +  "'>" + relativeAge(date, options)  + "</span>";
  };

  // mostly lifted from rails with a few amendments
  relativeAge = function(date, options) {
    options = options || {};
    var format = options.format || "tiny";

    var distance = Math.round((new Date() - date) / 1000);
    var distance_in_minutes = Math.round(distance / 60.0);

    var formatted;
    var t = function(key,opts){
      return Ember.String.i18n("dates." + format + "." + key, opts);
    };

    switch(true){

    case(distance_in_minutes < 1):
      formatted = t("less_than_x_minutes", {count: 1});
      break;
    case(distance_in_minutes >= 1 && distance_in_minutes <= 44):
      formatted = t("x_minutes", {count: distance_in_minutes});
      break;
    case(distance_in_minutes >= 45 && distance_in_minutes <= 89):
      formatted = t("about_x_hours", {count: 1});
      break;
    case(distance_in_minutes >= 90 && distance_in_minutes <= 1439):
      formatted = t("about_x_hours", {count: Math.round(distance_in_minutes / 60.0)});
      break;
    case(distance_in_minutes >= 1440 && distance_in_minutes <= 2519):
      formatted = t("x_days", {count: 1});
      break;
    case(distance_in_minutes >= 2520 && distance_in_minutes <= 129599):
      formatted = t("x_days", {count: Math.round(distance_in_minutes / 1440.0)});
      break;
    case(distance_in_minutes >= 129600 && distance_in_minutes <= 525599):
      formatted = t("x_months", {count: Math.round(distance_in_minutes / 43200.0)});
      break;
    default:
      var months = Math.round(distance_in_minutes / 43200.0);
      if (months < 24) {
        formatted = t("x_months", {count: months});
      } else {
        formatted = t("over_x_years", {count: Math.round(months / 12.0)});
      }
      break;
    }

    return formatted;
  };

  return {relativeAge: relativeAge, autoUpdatingRelativeAge: autoUpdatingRelativeAge, updateRelativeAge: updateRelativeAge};
})();
