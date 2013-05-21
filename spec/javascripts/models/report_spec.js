/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

describe("Discourse.Report", function() {

  function dateString(arg) {
    return Date.create(arg, 'en').format('{yyyy}-{MM}-{dd}');
  }

  function reportWithData(data) {
    var arr = [];
    data.each(function(val, index) {
      arr.push({x: dateString(index + ' days ago'), y: val});
    });
    return Discourse.Report.create({ type: 'topics', data: arr });
  }

  describe("todayCount", function() {
    it("returns the correct value", function() {
      expect( reportWithData([5,4,3,2,1]).get('todayCount') ).toBe(5);
    });
  });

  describe("yesterdayCount", function() {
    it("returns the correct value", function() {
      expect( reportWithData([5,4,3,2,1]).get('yesterdayCount') ).toBe(4);
    });
  });

  describe("sumDays", function() {
    it("adds the values for the given range of days, inclusive", function() {
      expect( reportWithData([1,2,3,5,8,13]).sumDays(2,4) ).toBe(16);
    });
  });

  describe("lastSevenDaysCount", function() {
    it("returns the correct value", function() {
      expect( reportWithData([100,9,8,7,6,5,4,3,200,300,400]).get('lastSevenDaysCount') ).toBe(42);
    });
  });

  describe("percentChangeString", function() {
    it("returns correct value when value increased", function() {
      expect( reportWithData([]).percentChangeString(8,5) ).toBe("+60%");
    });

    it("returns correct value when value decreased", function() {
      expect( reportWithData([]).percentChangeString(2,8) ).toBe("-75%");
    });

    it("returns 0 when value is unchanged", function() {
      expect( reportWithData([]).percentChangeString(8,8) ).toBe("0%");
    });

    it("returns Infinity when previous value was 0", function() {
      expect( reportWithData([]).percentChangeString(8,0) ).toBe(null);
    });

    it("returns -100 when yesterday's value was 0", function() {
      expect( reportWithData([]).percentChangeString(0,8) ).toBe('-100%');
    });

    it("returns NaN when both yesterday and the previous day were both 0", function() {
      expect( reportWithData([]).percentChangeString(0,0) ).toBe(null);
    });
  });

  describe("yesterdayCountTitle", function() {
    it("displays percent change and previous value", function(){
      var title = reportWithData([6,8,5,2,1]).get('yesterdayCountTitle')
      expect( title.indexOf('+60%') ).not.toBe(-1);
      expect( title ).toMatch("Was 5");
    });

    it("handles when two days ago was 0", function() {
      var title = reportWithData([6,8,0,2,1]).get('yesterdayCountTitle')
      expect( title ).toMatch("Was 0");
      expect( title ).not.toMatch("%");
    });
  });

  describe("sevenDayCountTitle", function() {
    it("displays percent change and previous value", function(){
      var title = reportWithData([100,1,1,1,1,1,1,1,2,2,2,2,2,2,2,100,100]).get('sevenDayCountTitle');
      expect( title ).toMatch("-50%");
      expect( title ).toMatch("Was 14");
    });
  });

  describe("thirtyDayCountTitle", function() {
    it("displays percent change and previous value", function(){
      var report = reportWithData([5,5,5,5]);
      report.set('prev30Days', 10);
      var title = report.get('thirtyDayCountTitle');
      expect( title.indexOf('+50%') ).not.toBe(-1);
      expect( title ).toMatch("Was 10");
    });
  });
});
