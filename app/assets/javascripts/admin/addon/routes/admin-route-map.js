export default function () {
  this.route("admin", { resetNamespace: true }, function () {
    this.route("dashboard", { path: "/" }, function () {
      this.route("general", { path: "/" });
      this.route("admin.dashboardModeration", {
        path: "/dashboard/moderation",
        resetNamespace: true,
      });
      this.route("admin.dashboardSecurity", {
        path: "/dashboard/security",
        resetNamespace: true,
      });
      this.route("admin.dashboardReports", {
        path: "/dashboard/reports",
        resetNamespace: true,
      });
    });

    this.route(
      "adminSiteSettings",
      { path: "/site_settings", resetNamespace: true },
      function () {
        this.route("adminSiteSettingsCategory", {
          path: "category/:category_id",
          resetNamespace: true,
        });
      }
    );

    this.route(
      "adminEmailLogs",
      { path: "/email-logs", resetNamespace: true },
      function () {
        this.route("sent", { path: "/" });
        this.route("skipped");
        this.route("bounced");
        this.route("received");
        this.route("rejected");
      }
    );

    this.route(
      "adminEmail",
      { path: "/email", resetNamespace: true },
      function () {
        this.route("settings", { path: "/" });
        this.route("serverSettings", { path: "/server-settings" });
        this.route("previewDigest", { path: "/preview-digest" });
        this.route("advancedTest", { path: "/advanced-test" });
        this.route(
          "adminEmailTemplates",
          { path: "/templates", resetNamespace: true },
          function () {
            this.route("edit", { path: "/:id" });
          }
        );
      }
    );

    this.route(
      "adminCustomize",
      { path: "/customize", resetNamespace: true },
      function () {
        this.route("colors");
        this.route("colors-show", { path: "/colors/:scheme_id" });
        this.route(
          "adminCustomizeThemes",
          { path: "/:type", resetNamespace: true },
          function () {
            this.route("show", { path: "/:theme_id" }, function () {
              this.route("schema", { path: "schema/:setting_name" });
            });
            this.route("edit", { path: "/:theme_id/:target/:field_name/edit" });
          }
        );
        this.route(
          "adminSiteText",
          { path: "/site_texts", resetNamespace: true },
          function () {
            this.route("edit", { path: "/:id" });
          }
        );
        this.route(
          "adminEmbedding",
          {
            path: "/embedding",
            resetNamespace: true,
          },
          function () {
            this.route("index", { path: "/" });
            this.route("settings");
            this.route("postsAndTopics", { path: "/posts_and_topics" });
            this.route("crawlers");
            this.route("new");
            this.route("edit", { path: "/:id" });
          }
        );
        this.route("adminCustomizeRobotsTxt", {
          path: "/robots",
          resetNamespace: true,
        });
        this.route(
          "adminCustomizeEmailStyle",
          { path: "/email_style", resetNamespace: true },
          function () {
            this.route("edit", { path: "/:field_name" });
          }
        );
        this.route(
          "adminCustomizeFormTemplates",
          { path: "/form-templates", resetNamespace: true },
          function () {
            this.route("new");
            this.route("edit", { path: "/:id" });
          }
        );
        this.route(
          "adminWatchedWords",
          { path: "/watched_words", resetNamespace: true },
          function () {
            this.route("action", { path: "/action/:action_id" });
          }
        );
      }
    );

    this.route("adminApi", { path: "/api", resetNamespace: true }, function () {
      this.route(
        "adminApiKeys",
        { path: "/keys", resetNamespace: true },
        function () {
          this.route("settings");
          this.route("show", { path: "/:api_key_id" });
          this.route("new");
        }
      );

      this.route(
        "adminWebHooks",
        { path: "/web_hooks", resetNamespace: true },
        function () {
          this.route("new");
          this.route("show", { path: "/:web_hook_id" });
          this.route("edit", { path: "/:web_hook_id/edit" });
        }
      );
    });

    this.route(
      "admin.backups",
      { path: "/backups", resetNamespace: true },
      function () {
        this.route("logs");
        this.route("settings");
      }
    );

    this.route(
      "adminReports",
      { path: "/reports", resetNamespace: true },
      function () {
        this.route("index", { path: "/" });
        this.route("show", { path: ":type" });
        this.route("dashboardSettings", { path: "dashboard-settings" });
      }
    );

    this.route(
      "adminLogs",
      { path: "/logs", resetNamespace: true },
      function () {
        this.route("staffActionLogs", { path: "/staff_action_logs" });
        this.route("screenedEmails", { path: "/screened_emails" });
        this.route("screenedIpAddresses", { path: "/screened_ip_addresses" });
        this.route("screenedUrls", { path: "/screened_urls" });
        this.route(
          "adminSearchLogs",
          { path: "/search_logs", resetNamespace: true },
          function () {
            this.route("index", { path: "/" });
            this.route("term");
          }
        );
      }
    );

    this.route(
      "adminUsers",
      { path: "/users", resetNamespace: true },
      function () {
        this.route("settings");
        this.route(
          "adminUser",
          { path: "/:user_id/:username", resetNamespace: true },
          function () {
            this.route("badges");
            this.route("tl3Requirements", { path: "/tl3_requirements" });
          }
        );

        this.route(
          "adminUsersList",
          { path: "/list", resetNamespace: true },
          function () {
            this.route("show", { path: "/:filter" });
          }
        );
      }
    );

    this.route(
      "adminBadges",
      { path: "/badges", resetNamespace: true },
      function () {
        this.route("settings");
        this.route("award", { path: "/award/:badge_id" });
        this.route("show", { path: "/:badge_id" });
      }
    );

    this.route(
      "adminGroups",
      { path: "/groups", resetNamespace: true },
      function () {
        this.route("settings");
      }
    );

    this.route(
      "adminConfig",
      { path: "/config", resetNamespace: true },
      function () {
        this.route("flags", function () {
          this.route("index", { path: "/" });
          this.route("new");
          this.route("edit", { path: "/:flag_id" });
          this.route("settings");
        });

        this.route("about");
        this.route("login", { path: "/login-and-authentication" }, function () {
          this.route("settings", {
            path: "/",
          });
          this.route("authenticators");
          this.route("discourseconnect");
          this.route("oauth2");
          this.route("oidc");
          this.route("saml");
        });
        this.route("content", function () {
          this.route("categoriesAndTags", { path: "/" });
          this.route("settings");
          this.route("sharing");
          this.route("postsAndTopics", { path: "/posts-and-topics" });
          this.route("statsAndThresholds", { path: "/stats-and-thresholds" });
        });
        this.route("localization", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("notifications", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("search", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("legal", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("experimental", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("other", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("files", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("interface", function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route(
          "groupPermissions",
          { path: "/group-permissions" },
          function () {
            this.route("settings", {
              path: "/",
            });
          }
        );
        this.route("userDefaults", { path: "user-defaults" }, function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("siteAdmin", { path: "/site-admin" }, function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("trustLevels", { path: "/trust-levels" }, function () {
          this.route("settings", {
            path: "/",
          });
        });
        this.route("customize", function () {
          this.route("themes");
          this.route("components");
          this.route("themeSiteSettings", { path: "/theme-site-settings" });
        });
        this.route(
          "adminAnalytics",
          { path: "/analytics-and-seo", resetNamespace: true },
          function () {
            this.route("settings", {
              path: "/",
            });
          }
        );
        this.route(
          "adminPermalinks",
          { path: "/permalinks", resetNamespace: true },
          function () {
            this.route("new");
            this.route("index", { path: "/" });
            this.route("settings");
            this.route("edit", { path: "/:permalink_id" });
          }
        );
        this.route(
          "adminUserFields",
          { path: "/user-fields", resetNamespace: true },
          function () {
            this.route("new");
            this.route("edit", { path: "/:id/edit" });
            this.route("index", { path: "/" });
          }
        );
        this.route(
          "adminEmojis",
          { path: "/emoji", resetNamespace: true },
          function () {
            this.route("new");
            this.route("index", { path: "/" });
            this.route("settings");
          }
        );
        this.route("developer", function () {
          this.route("settings", { path: "/" });
        });
        this.route("logo");
        this.route("fonts");
        this.route("navigation", function () {
          this.route("settings", { path: "/" });
        });
        this.route("onebox", function () {
          this.route("settings", { path: "/" });
        });
        this.route("rate-limits", function () {
          this.route("settings", { path: "/" });
        });
        this.route("security", function () {
          this.route("settings", { path: "/" });
        });
        this.route("spam", function () {
          this.route("settings", { path: "/" });
        });

        this.route(
          "colorPalettes",
          {
            path: "/colors",
          },
          function () {
            this.route("show", {
              path: "/:palette_id",
            });
          }
        );
      }
    );
    this.route("schema", { path: "schema/:setting_name" });
    this.route(
      "adminPlugins",
      { path: "/plugins", resetNamespace: true },
      function () {
        this.route("index", { path: "/" });
        this.route("show", { path: "/:plugin_id" }, function () {
          this.route("settings");
        });
      }
    );

    this.route("admin.whatsNew", {
      path: "/whats-new",
      resetNamespace: true,
    });

    this.route(
      "adminSection",
      { path: "/section", resetNamespace: true },
      function () {
        this.route("account");
      }
    );

    this.route(
      "adminSearch",
      { path: "/search", resetNamespace: true },
      function () {
        this.route("index", { path: "/" });
      }
    );
  });
}
