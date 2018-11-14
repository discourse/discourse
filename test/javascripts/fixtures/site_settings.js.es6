export default {
  "/admin/site_settings": {
    site_settings: [
      {
        setting: "title",
        description: "The name of this site, as used in the title tag.",
        default: "Discourse",
        value: "Discourse",
        category: "required",
        preview: null,
        secret: false,
        type: "string"
      },
      {
        setting: "contact_email",
        description:
          "Email address of key contact responsible for this site. Used for critical notifications, as well as on the /about contact form for urgent matters.",
        default: "",
        value: "",
        category: "required",
        preview: null,
        secret: false,
        type: "email"
      },
      {
        setting: "site_contact_username",
        description:
          "A valid staff username to send all automated messages from. If left blank the default System account will be used.",
        default: "",
        value: "",
        category: "required",
        preview: null,
        secret: false,
        type: "username"
      },
      {
        setting: "logo",
        description: "Some logo",
        default: "",
        value: "/some/image",
        category: "required",
        preview: null,
        secret: false,
        type: "upload"
      },
      {
        setting: "top_menu",
        description:
          "Determine which items appear in the homepage navigation, and in what order. Example latest|new|unread|categories|top|read|posted|bookmarks",
        default: "latest|new|unread|top|categories",
        value: "latest|new|unread|top|categories",
        category: "basic",
        preview: null,
        secret: false,
        type: "list",
        choices: [
          "latest",
          "new",
          "unread",
          "top",
          "categories",
          "read",
          "posted",
          "bookmarks"
        ],
        list_type: "compact"
      }
    ],
    diags: {
      last_message_processed: null
    }
  }
};
