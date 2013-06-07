/*global expect:true describe:true it:true beforeEach:true afterEach:true spyOn:true */

describe("Discourse.Formatter", function() {
  var format = "tiny";
  var leaveAgo = false;
  var mins_ago = function(mins){
    return new Date((new Date()) - mins * 60 * 1000);
  };

  var formatMins = function(mins) {
    return Discourse.Formatter.relativeAge(mins_ago(mins), {format: format, leaveAgo: leaveAgo});
  };

  var formatHours = function(hours) {
    return formatMins(hours * 60);
  };

  var formatDays = function(days) {
    return formatHours(days * 24);
  };

  var formatMonths = function(months) {
    return formatDays(months * 30);
  };

  describe("relativeTime", function() {

    it("can format medium length dates", function() {
      format = "medium";
      var strip = function(html){
        return $(html).text();
      }

      var shortDate = function(days){
        return moment().subtract('days', days).format('D MMM');
      }

      var shortDateYear = function(days){
        return moment().subtract('days', days).format('D MMM, YYYY');
      }

      leaveAgo = true;
      expect(strip(formatMins(1.4))).toBe("1 minute ago");
      expect(strip(formatMins(2))).toBe("2 minutes ago");
      expect(strip(formatMins(56))).toBe("56 minutes ago");
      expect(strip(formatMins(57))).toBe("1 hour ago");
      expect(strip(formatHours(4))).toBe("4 hours ago");
      expect(strip(formatHours(22))).toBe("22 hours ago");
      expect(strip(formatHours(23))).toBe("1 day ago");
      expect(strip(formatDays(4.85))).toBe("4 days ago");

      leaveAgo = false;
      expect(strip(formatMins(0))).toBe("just now");
      expect(strip(formatMins(1.4))).toBe("1 minute");
      expect(strip(formatMins(2))).toBe("2 minutes");
      expect(strip(formatMins(56))).toBe("56 minutes");
      expect(strip(formatMins(57))).toBe("1 hour");
      expect(strip(formatHours(4))).toBe("4 hours");
      expect(strip(formatHours(22))).toBe("22 hours");
      expect(strip(formatHours(23))).toBe("1 day");
      expect(strip(formatDays(4.85))).toBe("4 days");

      expect(strip(formatDays(6))).toBe(shortDate(6));
      expect(strip(formatDays(100))).toBe(shortDate(100)); // eg: 23 Jan
      expect(strip(formatDays(500))).toBe(shortDateYear(500));

      expect($(formatDays(0)).attr("title")).toBe(moment().format('MMMM D, YYYY h:mma'));
      expect($(formatDays(0)).attr("class")).toBe("date");

    });

    it("can format dates", function() {
      format = "tiny";
      expect(formatMins(0)).toBe("< 1m");
      expect(formatMins(2)).toBe("2m");
      expect(formatMins(60)).toBe("1h");
      expect(formatHours(4)).toBe("4h");
      expect(formatDays(1)).toBe("1d");
      expect(formatDays(20)).toBe("20d");
      expect(formatMonths(3)).toBe("3mon");
      expect(formatMonths(23)).toBe("23mon");
      expect(formatMonths(24)).toBe("> 2y");
    });
  });

  describe("autoUpdatingRelativeAge", function(){
    it("can format dates", function(){
      var d = new Date();

      var $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d));

      expect($elem.data('format')).toBe("tiny");
      expect($elem.data('time')).toBe(d.getTime());
    });
  });

  describe("updateRelativeAge", function(){
    it("can update relative dates", function(){

      var d = new Date();
      var $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d));
      $elem.data('time', d.getTime() - 2 * 60 * 1000);

      Discourse.Formatter.updateRelativeAge($elem);

      expect($elem.html()).toBe("2m");

    });
  });
});
