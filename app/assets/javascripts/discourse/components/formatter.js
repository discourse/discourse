Discourse.Formatter = (function(){
  var updateRelativeAge, autoUpdatingRelativeAge, relativeAge, relativeAgeTiny, relativeAgeMedium;

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


  relativeAgeTiny = function(date, options){
    var format = "tiny";
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

  relativeAgeMedium = function(date, options){
    var displayDate, fiveDaysAgo, oneMinuteAgo, fullReadable, humanized, leaveAgo, val;

    leaveAgo = options.leaveAgo;

    if (!date) {
      return "&mdash;";
    }

    fullReadable = date.format("long");
    displayDate = "";
    fiveDaysAgo = (new Date()) - 432000000;
    oneMinuteAgo = (new Date()) - 60000;

    if (oneMinuteAgo <= date.getTime() && date.getTime() <= (new Date())) {
      displayDate = Em.String.i18n("now");
    } else if (fiveDaysAgo > (date.getTime())) {
      if ((new Date()).getFullYear() !== date.getFullYear()) {
        displayDate = date.format("short");
      } else {
        displayDate = date.format("short_no_year");
      }
    } else {
      humanized = date.relative();
      if (!humanized) {
        return "";
      }
      displayDate = humanized;
      if (!leaveAgo) {
        displayDate = (date.millisecondsAgo()).duration();
      }
    }
    return "<span class='date' title='" + fullReadable + "'>" + displayDate + "</span>";
  };

  // mostly lifted from rails with a few amendments
  relativeAge = function(date, options) {
    options = options || {};
    var format = options.format || "tiny";

    if(format === "tiny") {
      return relativeAgeTiny(date, options);
    } else if (format === "medium") {
      return relativeAgeMedium(date, options);
    }

    return "UNKNOWN FORMAT";
  };

  return {relativeAge: relativeAge, autoUpdatingRelativeAge: autoUpdatingRelativeAge, updateRelativeAge: updateRelativeAge};
})();
