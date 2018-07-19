export default {
  "/admin/reports/signups_timeout": {
    report: {
      type: "signups",
      title: "Signups",
      xaxis: "Day",
      yaxis: "Number of signups",
      description: "New account registrations for this period",
      data: null,
      start_date: "2018-06-16T00:00:00Z",
      end_date: "2018-07-16T23:59:59Z",
      prev_data: null,
      prev_start_date: "2018-05-17T00:00:00Z",
      prev_end_date: "2018-06-17T00:00:00Z",
      category_id: null,
      group_id: null,
      prev30Days: null,
      dates_filtering: true,
      report_key: "reports:signups_timeout::20180616:20180716::[:prev_period]:",
      labels: [
        { type: "date", properties: ["x"], title: "Day" },
        { type: "number", properties: ["y"], title: "Count" }
      ],
      processing: false,
      average: false,
      percent: false,
      higher_is_better: true,
      category_filtering: false,
      group_filtering: true,
      modes: ["table", "chart"],
      prev_period: 961,
      timeout: true
    }
  }
};
