const startDate = moment()
  .locale("en")
  .utc()
  .startOf("day")
  .subtract(1, "month");

const endDate = moment()
  .locale("en")
  .utc()
  .endOf("day");

const data = [
  851,
  3805,
  2437,
  3768,
  4476,
  3021,
  1285,
  1120,
  3932,
  2777,
  3298,
  3198,
  3601,
  1249,
  1046,
  3212,
  3358,
  3306,
  2618,
  2679,
  910,
  875,
  3877,
  2342,
  2305,
  3534,
  3713,
  1133,
  1350,
  4048,
  2523,
  1062
];

export default {
  "/admin/reports/page_view_total_reqs": {
    report: {
      type: "page_view_total_reqs",
      title: "Pageviews",
      xaxis: "Day",
      yaxis: "Total Pageviews",
      description: null,
      data: [...data].map((d, i) => {
        return {
          x: moment(startDate)
            .add(i, "days")
            .format("YYYY-MM-DD"),
          y: d
        };
      }),
      start_date: startDate.toISOString(),
      end_date: endDate.toISOString(),
      prev_data: null,
      prev_start_date: "2018-06-20T00:00:00Z",
      prev_end_date: "2018-07-23T00:00:00Z",
      category_id: null,
      group_id: null,
      prev30Days: 58110,
      dates_filtering: true,
      report_key: `reports:page_view_total_reqs:${startDate.format(
        "YYYYMMDD"
      )}:${endDate.format("YYYYMMDD")}:[:prev_period]:2`,
      labels: [
        { type: "date", property: "x", title: "Day" },
        { type: "number", property: "y", title: "Count" }
      ],
      processing: false,
      average: false,
      percent: false,
      higher_is_better: true,
      category_filtering: false,
      group_filtering: false,
      modes: ["table", "chart"],
      icon: "file",
      total: 921672
    }
  }
};
