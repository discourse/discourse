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
    it("displays the correct value", function() {
      expect( reportWithData([5,4,3,2,1]).get('todayCount') ).toBe(5);
    });
  });

  describe("yesterdayCount", function() {
    it("displays the correct value", function() {
      expect( reportWithData([5,4,3,2,1]).get('yesterdayCount') ).toBe(4);
    });
  });

  describe("sumDays", function() {
    it("adds the values for the given range of days, inclusive", function() {
      expect( reportWithData([1,2,3,5,8,13]).sumDays(2,4) ).toBe(16);
    });
  });

  describe("lastSevenDaysCount", function() {
    it("displays the correct value", function() {
      expect( reportWithData([100,9,8,7,6,5,4,3,200,300,400]).get('lastSevenDaysCount') ).toBe(42);
    });
  });

});
