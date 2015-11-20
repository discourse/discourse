import { blank } from 'helpers/qunit-helpers';

module("Discourse.Report");

function reportWithData(data) {
  return Discourse.Report.create({
    type: 'topics',
    data: _.map(data, function(val, index) {
      return { x: moment().subtract(index, "days").format('YYYY-MM-DD'), y: val };
    })
  });
}

test("counts", function() {
  var report = reportWithData([5, 4, 3, 2, 1, 100, 99, 98, 1000]);

  equal(report.get('todayCount'), 5);
  equal(report.get('yesterdayCount'), 4);
  equal(report.valueFor(2, 4), 6, "adds the values for the given range of days, inclusive");
  equal(report.get('lastSevenDaysCount'), 307, "sums 7 days excluding today");

  report.set("method", "average");
  equal(report.valueFor(2, 4), 2, "averages the values for the given range of days");
});

test("percentChangeString", function() {
  var report = reportWithData([]);

  equal(report.percentChangeString(8, 5), "+60%", "value increased");
  equal(report.percentChangeString(2, 8), "-75%", "value decreased");
  equal(report.percentChangeString(8, 8), "0%", "value unchanged");
  blank(report.percentChangeString(8, 0), "returns blank when previous value was 0");
  equal(report.percentChangeString(0, 8), "-100%", "yesterday was 0");
  blank(report.percentChangeString(0, 0), "returns blank when both were 0");
});

test("yesterdayCountTitle with valid values", function() {
  var title = reportWithData([6,8,5,2,1]).get('yesterdayCountTitle');
  ok(title.indexOf('+60%') !== -1);
  ok(title.match(/Was 5/));
});

test("yesterdayCountTitle when two days ago was 0", function() {
  var title = reportWithData([6,8,0,2,1]).get('yesterdayCountTitle');
  equal(title.indexOf('%'), -1);
  ok(title.match(/Was 0/));
});


test("sevenDayCountTitle", function() {
  var title = reportWithData([100,1,1,1,1,1,1,1,2,2,2,2,2,2,2,100,100]).get('sevenDayCountTitle');
  ok(title.match(/-50%/));
  ok(title.match(/Was 14/));
});

test("thirtyDayCountTitle", function() {
  var report = reportWithData([5,5,5,5]);
  report.set('prev30Days', 10);
  var title = report.get('thirtyDayCountTitle');

  ok(title.indexOf('+50%') !== -1);
  ok(title.match(/Was 10/));
});
