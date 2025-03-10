export default {
  "/admin/reports.json": {
    reports: [
      {
        type: "staff_logins",
        title: "Admin Logins",
        description: "List of admin login times with locations.",
        description_link: null,
      },
      {
        type: "page_view_anon_browser_reqs",
        title: "Anonymous Browser Pageviews",
        description:
          "Number of pageviews by anonymous visitors using real browsers.",
        description_link: null,
      },
      {
        type: "bookmarks",
        title: "Bookmarks",
        description: "Number of new topics and posts bookmarked.",
        description_link: null,
      },
      {
        type: "consolidated_api_requests",
        title: "Consolidated API Requests",
        description: "API requests for regular API keys and user API keys.",
        description_link: null,
      },
      {
        type: "dau_by_mau",
        title: "DAU/MAU",
        description:
          "Number of members that logged in in the last day divided by number of members that logged in in the last month – returns a % which indicates community 'stickiness'. Aim for \u003E20%.",
        description_link: null,
      },
    ],
  },
};
