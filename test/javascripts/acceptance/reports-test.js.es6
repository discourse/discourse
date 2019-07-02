import { acceptance } from "helpers/qunit-helpers";

acceptance("Reports", {
  loggedIn: true
});

QUnit.test("Visit reports page", async assert => {
  await visit("/admin/reports");

  assert.equal($(".reports-list .report").length, 1);

  const $report = $(".reports-list .report:first-child");

  assert.equal(
    $report
      .find(".report-title")
      .html()
      .trim(),
    "My report"
  );

  assert.equal(
    $report
      .find(".report-description")
      .html()
      .trim(),
    "List of my activities"
  );
});

QUnit.test("Visit report page", async assert => {
  // eslint-disable-next-line
  server.get("/admin/reports/bulk", () => [
    200,
    { "Content-Type": "application/json" },
    {
      reports: [
        {
          type: "staff_logins",
          title: "Admin Logins",
          xaxis: null,
          yaxis: null,
          description: "List of admin login times with locations.",
          data: [
            {
              avatar_template:
                "/letter_avatar_proxy/v4/letter/q/a4c791/{size}.png",
              user_id: 4,
              username: "codinghorror",
              location: null,
              created_at: "2019-06-10T00:00:00.000Z"
            }
          ],
          start_date: "2019-06-01T00:00:00Z",
          end_date: "2019-07-01T23:59:59Z",
          prev_data: null,
          prev_start_date: "2019-04-30T00:00:00Z",
          prev_end_date: "2019-06-01T00:00:00Z",
          prev30Days: null,
          dates_filtering: true,
          report_key:
            "reports:staff_logins:20190601:20190702:[:prev_period]:50:4",
          primary_color: "rgba(0,136,204,1)",
          secondary_color: "rgba(0,136,204,0.1)",
          available_filters: [],
          labels: [
            {
              type: "user",
              properties: {
                username: "username",
                id: "user_id",
                avatar: "avatar_template"
              },
              title: "User"
            },
            { property: "location", title: "Location" },
            { property: "created_at", type: "precise_date", title: "Login at" }
          ],
          average: false,
          percent: false,
          higher_is_better: true,
          modes: ["table"],
          limit: 50
        }
      ]
    }
  ]);

  await visit("/admin/reports/staff_logins");
  assert.ok(exists(".export-csv-btn"));
});
