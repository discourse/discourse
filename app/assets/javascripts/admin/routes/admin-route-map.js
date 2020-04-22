export default function() {
  this.route("admin", { resetNamespace: true }, function() {
    this.route("dashboard", { path: "/" }, function() {
      this.route("general", { path: "/" });
      this.route("admin.dashboardModeration", {
        path: "/dashboard/moderation",
        resetNamespace: true
      });
      this.route("admin.dashboardSecurity", {
        path: "/dashboard/security",
        resetNamespace: true
      });
      this.route("admin.dashboardReports", {
        path: "/dashboard/reports",
        resetNamespace: true
      });
    });

    this.route(
      "adminSiteSettings",
      { path: "/site_settings", resetNamespace: true },
      function() {
        this.route("adminSiteSettingsCategory", {
          path: "category/:category_id",
          resetNamespace: true
        });
      }
    );

    this.route(
      "adminEmail",
      { path: "/email", resetNamespace: true },
      function() {
        this.route("sent");
        this.route("skipped");
        this.route("bounced");
        this.route("received");
        this.route("rejected");
        this.route("previewDigest", { path: "/preview-digest" });
        this.route("advancedTest", { path: "/advanced-test" });
      }
    );

    this.route(
      "adminCustomize",
      { path: "/customize", resetNamespace: true },
      function() {
        this.route("colors", function() {
          this.route("show", { path: "/:scheme_id" });
        });

        this.route(
          "adminCustomizeThemes",
          { path: "themes", resetNamespace: true },
          function() {
            this.route("show", { path: "/:theme_id" });
            this.route("edit", { path: "/:theme_id/:target/:field_name/edit" });
          }
        );

        this.route(
          "adminSiteText",
          { path: "/site_texts", resetNamespace: true },
          function() {
            this.route("edit", { path: "/:id" });
          }
        );

        this.route("adminUserFields", {
          path: "/user_fields",
          resetNamespace: true
        });
        this.route("adminEmojis", { path: "/emojis", resetNamespace: true });
        this.route("adminPermalinks", {
          path: "/permalinks",
          resetNamespace: true
        });
        this.route("adminEmbedding", {
          path: "/embedding",
          resetNamespace: true
        });
        this.route(
          "adminCustomizeEmailTemplates",
          { path: "/email_templates", resetNamespace: true },
          function() {
            this.route("edit", { path: "/:id" });
          }
        );
        this.route("adminCustomizeRobotsTxt", {
          path: "/robots",
          resetNamespace: true
        });
        this.route(
          "adminCustomizeEmailStyle",
          { path: "/email_style", resetNamespace: true },
          function() {
            this.route("edit", { path: "/:field_name" });
          }
        );
      }
    );

    this.route("adminApi", { path: "/api", resetNamespace: true }, function() {
      this.route(
        "adminApiKeys",
        { path: "/keys", resetNamespace: true },
        function() {
          this.route("show", { path: "/:api_key_id" });
          this.route("new", { path: "/new" });
        }
      );

      this.route(
        "adminWebHooks",
        { path: "/web_hooks", resetNamespace: true },
        function() {
          this.route("show", { path: "/:web_hook_id" });
          this.route("showEvents", { path: "/:web_hook_id/events" });
        }
      );
    });

    this.route(
      "admin.backups",
      { path: "/backups", resetNamespace: true },
      function() {
        this.route("logs");
      }
    );

    this.route(
      "adminReports",
      { path: "/reports", resetNamespace: true },
      function() {
        this.route("show", { path: ":type" });
      }
    );

    this.route(
      "adminLogs",
      { path: "/logs", resetNamespace: true },
      function() {
        this.route("staffActionLogs", { path: "/staff_action_logs" });
        this.route("screenedEmails", { path: "/screened_emails" });
        this.route("screenedIpAddresses", { path: "/screened_ip_addresses" });
        this.route("screenedUrls", { path: "/screened_urls" });
        this.route(
          "adminSearchLogs",
          { path: "/search_logs", resetNamespace: true },
          function() {
            this.route("index", { path: "/" });
            this.route("term", { path: "/term" });
          }
        );
        this.route(
          "adminWatchedWords",
          { path: "/watched_words", resetNamespace: true },
          function() {
            this.route("index", { path: "/" });
            this.route("action", { path: "/action/:action_id" });
          }
        );
      }
    );

    this.route(
      "adminUsers",
      { path: "/users", resetNamespace: true },
      function() {
        this.route(
          "adminUser",
          { path: "/:user_id/:username", resetNamespace: true },
          function() {
            this.route("badges");
            this.route("tl3Requirements", { path: "/tl3_requirements" });
          }
        );

        this.route(
          "adminUsersList",
          { path: "/list", resetNamespace: true },
          function() {
            this.route("show", { path: "/:filter" });
          }
        );
      }
    );

    this.route(
      "adminBadges",
      { path: "/badges", resetNamespace: true },
      function() {
        this.route("award", { path: "/award/:badge_id" });
        this.route("show", { path: "/:badge_id" });
      }
    );

    this.route(
      "adminPlugins",
      { path: "/plugins", resetNamespace: true },
      function() {
        this.route("index", { path: "/" });
      }
    );
  });
}
