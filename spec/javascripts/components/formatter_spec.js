/*global expect:true describe:true it:true beforeEach:true afterEach:true spyOn:true */

describe("Discourse.Formatter", function() {

  describe("relativeTime", function() {

    it("can format dates", function() {
      var mins_ago = function(mins){
        return new Date((new Date()) - mins * 60 * 1000);
      };

      var formatMins = function(mins) {
        return Discourse.Formatter.relativeAge(mins_ago(mins));
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
