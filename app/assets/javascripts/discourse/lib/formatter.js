/*jshint onecase:true */

Discourse.Formatter = (function(){

  var updateRelativeAge, autoUpdatingRelativeAge, relativeAge, relativeAgeTiny,
      relativeAgeMedium, relativeAgeMediumSpan, longDate, toTitleCase,
      shortDate, shortDateNoYear, tinyDateYear, breakUp;

  breakUp = function(string, maxLength){
    if(string.length <= maxLength) {
      return string;
    }

    var firstPart = string.substr(0, maxLength);

    // work backward to split stuff like ABPoop to AB Poop
    var i;
    for(i=firstPart.length-1;i>0;i--){
      if(firstPart[i].match(/[A-Z]/)){
        break;
      }
    }

    // work forwards to split stuff like ab111 to ab 111
    if(i===0) {
      for(i=1;i<firstPart.length;i++){
        if(firstPart[i].match(/[^a-z]/)){
          break;
        }
      }
    }

    if (i > 0 && i < firstPart.length) {
      var offset = 0;
      if(string[i] === "_") {
        offset = 1;
      }
      return string.substr(0, i + offset) + " " + string.substring(i + offset);
    } else {
      return firstPart + " " + string.substr(maxLength);
    }
  };

  shortDate = function(date){
    return moment(date).shortDate();
  };

  shortDateNoYear = function(date) {
    return moment(date).shortDateNoYear();
  };

  tinyDateYear = function(date) {
    return moment(date).format("D MMM 'YY");
  };

  // http://stackoverflow.com/questions/196972/convert-string-to-title-case-with-javascript
  // TODO: locale support ?
  toTitleCase = function toTitleCase(str)
  {
    return str.replace(/\w\S*/g, function(txt){
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
  };

  longDate = function(dt) {
    if (!dt) return;

    return moment(dt).longDate();
  };

  updateRelativeAge = function(elems) {
    // jQuery .each
    elems.each(function(){
      var $this = $(this);
      $this.html(relativeAge(new Date($this.data('time')), {format: $this.data('format'), wrapInSpan: false}));
    });
  };

  autoUpdatingRelativeAge = function(date,options) {

    if (!date) return "";

    options = options || {};
    var format = options.format || "tiny";

    var append = "";

    if(format === 'medium') {
      append = " date";
      if(options.leaveAgo) {
        format = 'medium-with-ago';
      }
      options.wrapInSpan = false;
    }

    if (options.title) {
      append += "' title='" + longDate(date);
    }

    return "<span class='relative-date" + append + "' data-time='" + date.getTime() + "' data-format='" + format +  "'>" + relativeAge(date, options)  + "</span>";
  };


  relativeAgeTiny = function(date, options){
    var format = "tiny";
    var distance = Math.round((new Date() - date) / 1000);
    var distanceInMinutes = Math.round(distance / 60.0);

    var formatted;
    var t = function(key,opts){
      return I18n.t("dates." + format + "." + key, opts);
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
    case(Discourse.SiteSettings.relative_date_duration === 0 && distanceInMinutes <= 525599):
      formatted = shortDateNoYear(date);
      break;
    case(distanceInMinutes >= 1440 && distanceInMinutes <= 2519):
      formatted = t("x_days", {count: 1});
      break;
    case(distanceInMinutes >= 2520 && distanceInMinutes <= ((Discourse.SiteSettings.relative_date_duration||14) * 1440)):
      formatted = t("x_days", {count: Math.round(distanceInMinutes / 1440.0)});
      break;
    default:
      if(date.getFullYear() === new Date().getFullYear()) {
        formatted = shortDateNoYear(date);
      } else {
        formatted = tinyDateYear(date);
      }
      break;
    }

    return formatted;
  };

  relativeAgeMediumSpan = function(distance, leaveAgo) {
    var formatted, distanceInMinutes;

    distanceInMinutes = Math.round(distance / 60.0);

    var t = function(key, opts){
      return I18n.t("dates.medium" + (leaveAgo?"_with_ago":"") + "." + key, opts);
    };

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
    return formatted || '&mdash';
  };

  relativeAgeMedium = function(date, options){
    var displayDate, fiveDaysAgo, oneMinuteAgo, fullReadable, leaveAgo, val;
    var wrapInSpan = options.wrapInSpan === false ? false : true;

    leaveAgo = options.leaveAgo;
    var distance = Math.round((new Date() - date) / 1000);

    if (!date) {
      return "&mdash;";
    }

    fullReadable = longDate(date);
    displayDate = "";
    fiveDaysAgo = 432000;
    oneMinuteAgo = 60;

    if (distance < oneMinuteAgo) {
      displayDate = I18n.t("now");
    } else if (distance > fiveDaysAgo) {
      if ((new Date()).getFullYear() !== date.getFullYear()) {
        displayDate = shortDate(date);
      } else {
        displayDate = moment(date).shortDateNoYear();
      }
    } else {
      displayDate = relativeAgeMediumSpan(distance, leaveAgo);
    }
    if(wrapInSpan) {
      return "<span class='date' title='" + fullReadable + "'>" + displayDate + "</span>";
    } else {
      return displayDate;
    }
  };

  // mostly lifted from rails with a few amendments
  relativeAge = function(date, options) {
    options = options || {};
    var format = options.format || "tiny";

    if(format === "tiny") {
      return relativeAgeTiny(date, options);
    } else if (format === "medium") {
      return relativeAgeMedium(date, options);
    } else if (format === 'medium-with-ago') {
      return relativeAgeMedium(date, _.extend(options, {format: 'medium', leaveAgo: true}));
    }

    return "UNKNOWN FORMAT";
  };

  return {
    longDate: longDate,
    relativeAge: relativeAge,
    autoUpdatingRelativeAge: autoUpdatingRelativeAge,
    updateRelativeAge: updateRelativeAge,
    toTitleCase: toTitleCase,
    shortDate: shortDate,
    breakUp: breakUp
  };
})();
