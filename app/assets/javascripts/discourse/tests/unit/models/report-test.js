import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { setPrefix } from "discourse-common/lib/get-url";

function reportWithData(data) {
  const store = getOwner(this).lookup("service:store");

  return store.createRecord("report", {
    type: "topics",
    data: data.map((val, index) => ({
      x: moment().subtract(index, "days").format("YYYY-MM-DD"),
      y: val,
    })),
  });
}

module("Unit | Model | report", function (hooks) {
  setupTest(hooks);

  test("counts", function (assert) {
    const report = reportWithData.call(
      this,
      [5, 4, 3, 2, 1, 100, 99, 98, 1000]
    );

    assert.strictEqual(report.todayCount, 5);
    assert.strictEqual(report.yesterdayCount, 4);
    assert.strictEqual(
      report.valueFor(2, 4),
      6,
      "adds the values for the given range of days, inclusive"
    );
    assert.strictEqual(
      report.lastSevenDaysCount,
      307,
      "sums 7 days excluding today"
    );

    report.set("type", "time_to_first_response");
    assert.strictEqual(
      report.valueFor(2, 4),
      2,
      "averages the values for the given range of days"
    );
  });

  test("percentChangeString", function (assert) {
    const report = reportWithData.call(this, []);

    assert.strictEqual(
      report.percentChangeString(5, 8),
      "+60%",
      "value increased"
    );
    assert.strictEqual(
      report.percentChangeString(8, 2),
      "-75%",
      "value decreased"
    );
    assert.strictEqual(
      report.percentChangeString(8, 8),
      "0%",
      "value unchanged"
    );
    assert.blank(
      report.percentChangeString(0, 8),
      "returns blank when previous value was 0"
    );
    assert.strictEqual(
      report.percentChangeString(8, 0),
      "-100%",
      "yesterday was 0"
    );
    assert.blank(
      report.percentChangeString(0, 0),
      "returns blank when both were 0"
    );
  });

  test("yesterdayCountTitle with valid values", function (assert) {
    const title = reportWithData.call(
      this,
      [6, 8, 5, 2, 1]
    ).yesterdayCountTitle;
    assert.true(title.includes("+60%"));
    assert.true(/Was 5/.test(title));
  });

  test("yesterdayCountTitle when two days ago was 0", function (assert) {
    const title = reportWithData.call(
      this,
      [6, 8, 0, 2, 1]
    ).yesterdayCountTitle;
    assert.false(title.includes("%"));
    assert.true(/Was 0/.test(title));
  });

  test("sevenDaysCountTitle", function (assert) {
    const title = reportWithData.call(
      this,
      [100, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 100, 100]
    ).sevenDaysCountTitle;
    assert.true(/-50%/.test(title));
    assert.true(/Was 14/.test(title));
  });

  test("thirtyDaysCountTitle", function (assert) {
    const report = reportWithData.call(this, [5, 5, 5, 5]);
    report.set("prev30Days", 10);

    assert.true(report.thirtyDaysCountTitle.includes("+50%"));
    assert.true(/Was 10/.test(report.thirtyDaysCountTitle));

    const report2 = reportWithData.call(this, [5, 5, 5, 5]);
    report2.set("prev_period", 20);

    assert.true(report2.thirtyDaysCountTitle.includes("-25%"));
    assert.true(/Was 20/.test(report2.thirtyDaysCountTitle));
  });

  test("sevenDaysTrend", function (assert) {
    let report;
    let trend;

    report = reportWithData.call(
      this,
      [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "no-change");

    report = reportWithData.call(
      this,
      [0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "high-trending-up");

    report = reportWithData.call(
      this,
      [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "trending-up");

    report = reportWithData.call(
      this,
      [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "high-trending-down");

    report = reportWithData.call(
      this,
      [0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "trending-down");
  });

  test("yesterdayTrend", function (assert) {
    let report;
    let trend;

    report = reportWithData.call(this, [0, 1, 1]);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "no-change");

    report = reportWithData.call(this, [0, 1, 0]);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "high-trending-up");

    report = reportWithData.call(this, [0, 1.1, 1]);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "trending-up");

    report = reportWithData.call(this, [0, 0, 1]);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "high-trending-down");

    report = reportWithData.call(this, [0, 1, 1.1]);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "trending-down");
  });

  test("thirtyDaysTrend", function (assert) {
    let report;
    let trend;

    report = reportWithData.call(
      this,
      [
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1,
      ]
    );
    report.set("prev30Days", 30);
    trend = report.thirtyDaysTrend;
    assert.strictEqual(trend, "no-change");

    report = reportWithData.call(
      this,
      [
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1,
      ]
    );
    report.set("prev30Days", 0);
    trend = report.thirtyDaysTrend;
    assert.strictEqual(trend, "high-trending-up");

    report = reportWithData.call(
      this,
      [
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1,
      ]
    );
    report.set("prev30Days", 25);
    trend = report.thirtyDaysTrend;
    assert.strictEqual(trend, "trending-up");

    report = reportWithData.call(
      this,
      [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0,
      ]
    );
    report.set("prev30Days", 60);
    trend = report.thirtyDaysTrend;
    assert.strictEqual(trend, "high-trending-down");

    report = reportWithData.call(
      this,
      [
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 0,
      ]
    );
    report.set("prev30Days", 35);
    trend = report.thirtyDaysTrend;
    assert.strictEqual(trend, "trending-down");
  });

  test("higher is better false", function (assert) {
    let report;
    let trend;

    report = reportWithData.call(this, [0, 1, 0]);
    report.set("higher_is_better", false);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "high-trending-down");

    report = reportWithData.call(this, [0, 1.1, 1]);
    report.set("higher_is_better", false);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "trending-down");

    report = reportWithData.call(this, [0, 0, 1]);
    report.set("higher_is_better", false);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "high-trending-up");

    report = reportWithData.call(this, [0, 1, 1.1]);
    report.set("higher_is_better", false);
    trend = report.yesterdayTrend;
    assert.strictEqual(trend, "trending-up");
  });

  test("small variation (-2/+2% change) is no-change", function (assert) {
    let report;
    let trend;

    report = reportWithData.call(
      this,
      [0, 1, 1, 1, 1, 1, 1, 0.9, 1, 1, 1, 1, 1, 1, 1]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "no-change");

    report = reportWithData.call(
      this,
      [0, 1, 1, 1, 1, 1, 1, 1.1, 1, 1, 1, 1, 1, 1, 1]
    );
    trend = report.sevenDaysTrend;
    assert.strictEqual(trend, "no-change");
  });

  test("average", function (assert) {
    let report;

    report = reportWithData.call(this, [5, 5, 5, 5, 5, 5, 5, 5]);

    report.set("average", true);
    assert.strictEqual(report.lastSevenDaysCount, 5);

    report.set("average", false);
    assert.strictEqual(report.lastSevenDaysCount, 35);
  });

  test("computed labels", function (assert) {
    const data = [
      {
        username: "joffrey",
        user_id: 1,
        user_avatar: "/",
        flag_count: "1876",
        time_read: 287362,
        note: "This is a long note",
        topic_id: 2,
        topic_title: "Test topic <html>",
        post_number: 3,
        post_raw: "This is the beginning of <html>",
        filesize: 582641,
      },
    ];

    const labels = [
      {
        type: "user",
        properties: {
          username: "username",
          id: "user_id",
          avatar: "user_avatar",
        },
        title: "Moderator",
      },
      { type: "number", property: "flag_count", title: "Flag count" },
      { type: "seconds", property: "time_read", title: "Time read" },
      { type: "text", property: "note", title: "Note" },
      {
        type: "topic",
        properties: {
          title: "topic_title",
          id: "topic_id",
        },
        title: "Topic",
      },
      {
        type: "post",
        properties: {
          topic_id: "topic_id",
          number: "post_number",
          truncated_raw: "post_raw",
        },
        title: "Post",
      },
      { type: "bytes", property: "filesize", title: "Filesize" },
    ];

    const store = getOwner(this).lookup("service:store");
    const report = store.createRecord("report", {
      type: "topics",
      labels,
      data,
    });

    const row = report.data[0];
    const computedLabels = report.computedLabels;

    const usernameLabel = computedLabels[0];
    assert.strictEqual(usernameLabel.mainProperty, "username");
    assert.strictEqual(usernameLabel.sortProperty, "username");
    assert.strictEqual(usernameLabel.title, "Moderator");
    assert.strictEqual(usernameLabel.type, "user");
    const computedUsernameLabel = usernameLabel.compute(row);
    assert.strictEqual(
      computedUsernameLabel.formattedValue,
      "<a href='/admin/users/1/joffrey'><img loading='lazy' alt='' width='24' height='24' src='/' class='avatar' title='joffrey'><span class='username'>joffrey</span></a>"
    );
    assert.strictEqual(computedUsernameLabel.value, "joffrey");

    const flagCountLabel = computedLabels[1];
    assert.strictEqual(flagCountLabel.mainProperty, "flag_count");
    assert.strictEqual(flagCountLabel.sortProperty, "flag_count");
    assert.strictEqual(flagCountLabel.title, "Flag count");
    assert.strictEqual(flagCountLabel.type, "number");
    let computedFlagCountLabel = flagCountLabel.compute(row);
    assert.strictEqual(computedFlagCountLabel.formattedValue, "1.9k");
    assert.strictEqual(computedFlagCountLabel.value, 1876);
    computedFlagCountLabel = flagCountLabel.compute(row, {
      formatNumbers: false,
    });
    assert.strictEqual(computedFlagCountLabel.formattedValue, "1876");

    const timeReadLabel = computedLabels[2];
    assert.strictEqual(timeReadLabel.mainProperty, "time_read");
    assert.strictEqual(timeReadLabel.sortProperty, "time_read");
    assert.strictEqual(timeReadLabel.title, "Time read");
    assert.strictEqual(timeReadLabel.type, "seconds");
    const computedTimeReadLabel = timeReadLabel.compute(row);
    assert.strictEqual(computedTimeReadLabel.formattedValue, "3d");
    assert.strictEqual(computedTimeReadLabel.value, 287362);

    const noteLabel = computedLabels[3];
    assert.strictEqual(noteLabel.mainProperty, "note");
    assert.strictEqual(noteLabel.sortProperty, "note");
    assert.strictEqual(noteLabel.title, "Note");
    assert.strictEqual(noteLabel.type, "text");
    const computedNoteLabel = noteLabel.compute(row);
    assert.strictEqual(computedNoteLabel.formattedValue, "This is a long note");
    assert.strictEqual(computedNoteLabel.value, "This is a long note");

    const topicLabel = computedLabels[4];
    assert.strictEqual(topicLabel.mainProperty, "topic_title");
    assert.strictEqual(topicLabel.sortProperty, "topic_title");
    assert.strictEqual(topicLabel.title, "Topic");
    assert.strictEqual(topicLabel.type, "topic");
    const computedTopicLabel = topicLabel.compute(row);
    assert.strictEqual(
      computedTopicLabel.formattedValue,
      "<a href='/t/-/2'>Test topic &lt;html&gt;</a>"
    );
    assert.strictEqual(computedTopicLabel.value, "Test topic <html>");

    const postLabel = computedLabels[5];
    assert.strictEqual(postLabel.mainProperty, "post_raw");
    assert.strictEqual(postLabel.sortProperty, "post_raw");
    assert.strictEqual(postLabel.title, "Post");
    assert.strictEqual(postLabel.type, "post");
    const computedPostLabel = postLabel.compute(row);
    assert.strictEqual(
      computedPostLabel.formattedValue,
      "<a href='/t/-/2/3'>This is the beginning of &lt;html&gt;</a>"
    );
    assert.strictEqual(
      computedPostLabel.value,
      "This is the beginning of <html>"
    );

    const filesizeLabel = computedLabels[6];
    assert.strictEqual(filesizeLabel.mainProperty, "filesize");
    assert.strictEqual(filesizeLabel.sortProperty, "filesize");
    assert.strictEqual(filesizeLabel.title, "Filesize");
    assert.strictEqual(filesizeLabel.type, "bytes");
    const computedFilesizeLabel = filesizeLabel.compute(row);
    assert.strictEqual(computedFilesizeLabel.formattedValue, "569.0 KB");
    assert.strictEqual(computedFilesizeLabel.value, 582641);

    // subfolder support
    setPrefix("/forum");

    const postLink = computedLabels[5].compute(row).formattedValue;
    assert.strictEqual(
      postLink,
      "<a href='/forum/t/-/2/3'>This is the beginning of &lt;html&gt;</a>"
    );

    const topicLink = computedLabels[4].compute(row).formattedValue;
    assert.strictEqual(
      topicLink,
      "<a href='/forum/t/-/2'>Test topic &lt;html&gt;</a>"
    );

    const userLink = computedLabels[0].compute(row).formattedValue;
    assert.strictEqual(
      userLink,
      "<a href='/forum/admin/users/1/joffrey'><img loading='lazy' alt='' width='24' height='24' src='/forum/' class='avatar' title='joffrey'><span class='username'>joffrey</span></a>"
    );
  });
});
