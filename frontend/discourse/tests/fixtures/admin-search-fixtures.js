export default {
  "/admin/search/all.json": {
    settings: [
      {
        setting: "title",
        humanized_name: "Title",
        description:
          "The name of this site. Visible to all visitors including anonymous users.",
        keywords: [],
        category: "required",
        primary_area: "about",
      },
      {
        setting: "site_description",
        humanized_name: "Site description",
        description:
          "Describe this site in one sentence. Visible to all visitors including anonymous users.",
        keywords: [],
        category: "required",
        primary_area: "about",
      },
    ],
    themes_and_components: [
      {
        id: 57,
        name: "Air Theme",
        description: "A clean and modern theme for Discourse",
        created_at: "2024-10-16T05:10:28.695Z",
        updated_at: "2024-10-16T05:10:36.298Z",
        component: false,
      },
      {
        id: 59,
        name: "Clickable Topic",
        description: null,
        created_at: "2024-10-16T05:10:33.445Z",
        updated_at: "2024-10-16T05:10:33.445Z",
        component: true,
      },
    ],
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
          "Number of pageviews by anonymous visitors using real browsers. Anonym to test word matching.",
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
          "Number of members that logged in in the last day divided by number of members that logged in in the last month – returns a % which indicates community 'stickiness'. Aim for < 20%.",
        description_link: null,
      },
    ],
  },
};
