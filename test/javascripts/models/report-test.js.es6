import Report from 'admin/models/report';

QUnit.module("Report");

function reportWithData(data) {
  return Report.create({
    type: 'topics',
    data: _.map(data, function(val, index) {
      return { x: moment().subtract(index, "days").format('YYYY-MM-DD'), y: val };
    })
  });
}

QUnit.test("counts", assert => {
  var report = reportWithData([5, 4, 3, 2, 1, 100, 99, 98, 1000]);

  assert.equal(report.get('todayCount'), 5);
  assert.equal(report.get('yesterdayCount'), 4);
  assert.equal(report.valueFor(2, 4), 6, "adds the values for the given range of days, inclusive");
  assert.equal(report.get('lastSevenDaysCount'), 307, "sums 7 days excluding today");

  report.set("method", "average");
  assert.equal(report.valueFor(2, 4), 2, "averages the values for the given range of days");
});

QUnit.test("percentChangeString", assert => {
  var report = reportWithData([]);

  assert.equal(report.percentChangeString(8, 5), "+60%", "value increased");
  assert.equal(report.percentChangeString(2, 8), "-75%", "value decreased");
  assert.equal(report.percentChangeString(8, 8), "0%", "value unchanged");
  assert.blank(report.percentChangeString(8, 0), "returns blank when previous value was 0");
  assert.equal(report.percentChangeString(0, 8), "-100%", "yesterday was 0");
  assert.blank(report.percentChangeString(0, 0), "returns blank when both were 0");
});

QUnit.test("yesterdayCountTitle with valid values", assert => {
  var title = reportWithData([6,8,5,2,1]).get('yesterdayCountTitle');
  assert.ok(title.indexOf('+60%') !== -1);
  assert.ok(title.match(/Was 5/));
});

QUnit.test("yesterdayCountTitle when two days ago was 0", assert => {
  var title = reportWithData([6,8,0,2,1]).get('yesterdayCountTitle');
  assert.equal(title.indexOf('%'), -1);
  assert.ok(title.match(/Was 0/));
});


QUnit.test("sevenDayCountTitle", assert => {
  var title = reportWithData([100,1,1,1,1,1,1,1,2,2,2,2,2,2,2,100,100]).get('sevenDayCountTitle');
  assert.ok(title.match(/-50%/));
  assert.ok(title.match(/Was 14/));
});

QUnit.test("thirtyDayCountTitle", assert => {
  var report = reportWithData([5,5,5,5]);
  report.set('prev30Days', 10);
  var title = report.get('thirtyDayCountTitle');

  assert.ok(title.indexOf('+50%') !== -1);
  assert.ok(title.match(/Was 10/));
});