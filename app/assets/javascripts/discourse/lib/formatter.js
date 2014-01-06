Discourse.Formatter = (function(){

  var updateRelativeAge, autoUpdatingRelativeAge, relativeAge, relativeAgeTiny,
      relativeAgeMedium, relativeAgeMediumSpan, longDate, toTitleCase,
      shortDate, shortDateNoYear, tinyDateYear, breakUp;

    /*
  * memoize.js
  * by @philogb and @addyosmani
  * with further optimizations by @mathias
  * and @DmitryBaranovsk
  * perf tests: http://bit.ly/q3zpG3
  * Released under an MIT license.
  *
  * modified with cap by Sam
  */
  var cappedMemoize = function ( fn, max ) {
      fn.maxMemoize = max;
      fn.memoizeLength = 0;

      return function () {
          var args = Array.prototype.slice.call(arguments),
              hash = "",
              i = args.length;
          var currentArg = null;
          while (i--) {
              currentArg = args[i];
              hash += (currentArg === new Object(currentArg)) ?
              JSON.stringify(currentArg) : currentArg;
              if(!fn.memoize) {
                fn.memoize = {};
              }
          }
          if (hash in fn.memoize) {
            return fn.memoize[hash];
          } else {
            fn.memoizeLength++;
            if(fn.memoizeLength > max) {
              fn.memoizeLength = 0;
              fn.memoize = {};
            }
            var result = fn.apply(this, args);
            fn.memoize[hash] = result;
            return result;
          }
      };
  };

  breakUp = function(str, hint){
    var rval = [];
    var prev = str[0];
    var cur;
    var brk = "<wbr>&#8203;";

    var hintPos = [];
    if(hint) {
      hint = hint.toLowerCase().split(/\s+/).reverse();
      var current = 0;
      while(hint.length > 0) {
        var word = hint.pop();
        if(word !== str.substr(current, word.length).toLowerCase()) {
          break;
        }
        current += word.length;
        hintPos.push(current);
      }
    }

    rval.push(prev);
    for (var i=1;i<str.length;i++) {
      cur = str[i];
      if(prev.match(/[^0-9]/) && cur.match(/[0-9]/)){
        rval.push(brk);
      } else if(i>1 && prev.match(/[A-Z]/) && cur.match(/[a-z]/)){
        rval.pop();
        rval.push(brk);
        rval.push(prev);
      } else if(prev.match(/[^A-Za-z0-9]/) && cur.match(/[a-zA-Z0-9]/)){
        rval.push(brk);
      } else if(hintPos.indexOf(i) > -1) {
        rval.push(brk);
      }

      rval.push(cur);
      prev = cur;
    }

    return rval.join("");

  };

  breakUp = cappedMemoize(breakUp, 100);

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


  relativeAgeTiny = function(date){
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
    var displayDate, fiveDaysAgo, oneMinuteAgo, fullReadable, leaveAgo;
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
    breakUp: breakUp,
    cappedMemoize: cappedMemoize
  };
})();
