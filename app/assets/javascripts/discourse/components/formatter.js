Discourse.Formatter = (function(){

  var updateRelativeAge, autoUpdatingRelativeAge, relativeAge, relativeAgeTiny, relativeAgeMedium, relativeAgeMediumSpan, longDate;

  var shortDateNoYearFormat = Ember.String.i18n("dates.short_date_no_year");
  var longDateFormat = Ember.String.i18n("dates.long_date");
  var shortDateFormat = Ember.String.i18n("dates.short_date");

  longDate = function(dt) {
    return moment(dt).format(longDateFormat);
  };

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
    var distanceInMinutes = Math.round(distance / 60.0);

    var formatted;
    var t = function(key,opts){
      return Ember.String.i18n("dates." + format + "." + key, opts);
    };

    switch(true){

    case(distanceInMinutes < 1):
      formatted = t("less_than_x_minutes", {count: 1});
      break;
    case(distanceInMinutes >= 1 && distanceInMinutes <= 44):
      formatted = t("x_minutes", {count: distanceInMinutes});
      break;
    case(distanceInMinutes >= 45 && distanceInMinutes <= 89):
      formatted = t("about_x_hours", {count: 1});
      break;
    case(distanceInMinutes >= 90 && distanceInMinutes <= 1439):
      formatted = t("about_x_hours", {count: Math.round(distanceInMinutes / 60.0)});
      break;
    case(distanceInMinutes >= 1440 && distanceInMinutes <= 2519):
      formatted = t("x_days", {count: 1});
      break;
    case(distanceInMinutes >= 2520 && distanceInMinutes <= 129599):
      formatted = t("x_days", {count: Math.round(distanceInMinutes / 1440.0)});
      break;
    case(distanceInMinutes >= 129600 && distanceInMinutes <= 525599):
      formatted = t("x_months", {count: Math.round(distanceInMinutes / 43200.0)});
      break;
    default:
      var months = Math.round(distanceInMinutes / 43200.0);
      if (months < 24) {
        formatted = t("x_months", {count: months});
      } else {
        formatted = t("over_x_years", {count: Math.round(months / 12.0)});
      }
      break;
    }

    return formatted;
  };

  relativeAgeMediumSpan = function(distance, leaveAgo) {
    var formatted, distanceInMinutes;

    distanceInMinutes = Math.round(distance / 60.0);

    var t = function(key, opts){
      return Ember.String.i18n("dates.medium" + (leaveAgo?"_with_ago":"") + "." + key, opts);
    }

    switch(true){
    case(distanceInMinutes >= 1 && distanceInMinutes <= 56):
      formatted = t("x_minutes", {count: distanceInMinutes});
      break;
    case(distanceInMinutes >= 56 && distanceInMinutes <= 89):
      formatted = t("x_hours", {count: 1});
      break;
    case(distanceInMinutes >= 90 && distanceInMinutes <= 1379):
      formatted = t("x_hours", {count: Math.round(distanceInMinutes / 60.0)});
      break;
    case(distanceInMinutes >= 1380 && distanceInMinutes <= 2159):
      formatted = t("x_days", {count: 1});
      break;
    case(distanceInMinutes >= 2160):
      formatted = t("x_days", {count: Math.round((distanceInMinutes - 720.0) / 1440.0)});
      break;
    }

    return formatted;
  };

  relativeAgeMedium = function(date, options){
    var displayDate, fiveDaysAgo, oneMinuteAgo, fullReadable, leaveAgo, val;

    leaveAgo = options.leaveAgo;
    var distance = Math.round((new Date() - date) / 1000);

    if (!date) {
      return "&mdash;";
    }

    fullReadable = longDate(date);
    displayDate = "";
    fiveDaysAgo = 432000;
    oneMinuteAgo = 60;

    if (distance >= 0 && distance < oneMinuteAgo) {
      displayDate = Em.String.i18n("now");
    } else if (distance > fiveDaysAgo) {
      if ((new Date()).getFullYear() !== date.getFullYear()) {
        displayDate = moment(date).format(shortDateFormat);
      } else {
        displayDate = moment(date).format(shortDateNoYearFormat);
      }
    } else {
      displayDate = relativeAgeMediumSpan(distance, leaveAgo);
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

  return {
    longDate: longDate,
    relativeAge: relativeAge,
    autoUpdatingRelativeAge: autoUpdatingRelativeAge,
    updateRelativeAge: updateRelativeAge
  };
})();
