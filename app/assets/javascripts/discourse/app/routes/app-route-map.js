import Site from "discourse/models/site";
import { capitalize } from "@ember/string";

export default function () {
  // Error page
  this.route("exception", { path: "/exception" });
  this.route("exception-unknown", { path: "/404" });

  this.route("about", { path: "/about", resetNamespace: true });

  this.route("post", { path: "/p/:id" });

  // Topic routes
  this.route(
    "topic",
    { path: "/t/:slug/:id", resetNamespace: true },
    function () {
      this.route("fromParams", { path: "/" });
      this.route("fromParamsNear", { path: "/:nearPost" });
    }
  );

  this.route("topicBySlugOrId", { path: "/t/:slugOrId", resetNamespace: true });

  this.route("newCategory", { path: "/new-category" });
  this.route("editCategory", { path: "/c/*slug/edit" }, function () {
    this.route("tabs", { path: "/:tab" });
  });

  this.route("discovery", { path: "/", resetNamespace: true }, function () {
    // top by periods - legacy route
    Site.currentProp("periods").forEach((period) => {
      const top = "top" + capitalize(period);

      this.route(top, { path: "/top/" + period });
      this.route(top + "CategoryNone", {
        path: "/c/*category_slug_path_with_id/none/l/top/" + period,
      });
      this.route(top + "Category", {
        path: "/c/*category_slug_path_with_id/l/top/" + period,
      });
    });

    // filters (e.g. bookmarks, posted, read, unread, latest, top)
    Site.currentProp("filters").forEach((filter) => {
      this.route(filter, { path: "/" + filter });
      this.route(filter + "CategoryNone", {
        path: "/c/*category_slug_path_with_id/none/l/" + filter,
      });
      this.route(filter + "Category", {
        path: "/c/*category_slug_path_with_id/l/" + filter,
      });
    });

    this.route("filter", { path: "/filter" });

    this.route("categories");

    // default filter for a category
    this.route("categoryNone", { path: "/c/*category_slug_path_with_id/none" });
    this.route("categoryAll", { path: "/c/*category_slug_path_with_id/all" });
    this.route("category", { path: "/c/*category_slug_path_with_id" });
  });

  this.route("groups", { resetNamespace: true, path: "/g" }, function () {
    this.route("new", { path: "custom/new" });
  });

  this.route("group", { path: "/g/:name", resetNamespace: true }, function () {
    this.route("members");
    this.route("requests");

    this.route("activity", function () {
      this.route("posts");
      this.route("topics");
      this.route("mentions");
    });

    this.route("manage", function () {
      this.route("profile");
      this.route("membership");
      this.route("interaction");
      this.route("email");
      this.route("members");
      this.route("categories");
      this.route("tags");
      this.route("logs");
    });

    this.route("messages", function () {
      this.route("inbox");
      this.route("archive");
    });

    this.route("permissions");
  });

  // User routes
  this.route("users", { resetNamespace: true, path: "/u" });
  this.route("password-reset", { path: "/u/password-reset/:token" });
  this.route("account-created", { path: "/u/account-created" }, function () {
    this.route("resent");
    this.route("edit-email");
  });
  this.route(
    "user",
    { path: "/u/:username", resetNamespace: true },
    function () {
      this.route("profile-hidden");
      this.route("summary");
      this.route(
        "userActivity",
        { path: "/activity", resetNamespace: true },
        function () {
          this.route("topics");
          this.route("replies");
          this.route("likesGiven", { path: "likes-given" });
          this.route("bookmarks");
          this.route("bookmarksWithReminders", {
            path: "bookmarks-with-reminders",
          });
          this.route("pending");
          this.route("drafts");
          this.route("read");
        }
      );

      this.route(
        "userNotifications",
        { path: "/notifications", resetNamespace: true },
        function () {
          this.route("responses");
          this.route("likesReceived", { path: "likes-received" });
          this.route("mentions");
          this.route("edits");
        }
      );

      this.route("badges");
      this.route("deletedPosts", { path: "/deleted-posts" });

      this.route(
        "userPrivateMessages",
        { path: "/messages", resetNamespace: true },
        function () {
          this.route("user", { path: "/" }, function () {
            this.route("new");
            this.route("unread");
            this.route("archive");
            this.route("sent");
            this.route("warnings");
          });

          this.route("group", { path: "group/:name" }, function () {
            this.route("archive");
            this.route("new");
            this.route("unread");
          });

          this.route("tags", { path: "/tags" }, function () {
            this.route("show", { path: ":id" });
          });
        }
      );

      this.route("preferences", { resetNamespace: true }, function () {
        this.route("account");
        this.route("security");
        this.route("profile");
        this.route("emails");
        this.route("notifications");
        this.route("tracking");
        this.route("categories");
        this.route("users");
        this.route("tags");
        this.route("interface");
        this.route("apps");
        this.route("sidebar");

        this.route("email");
        this.route("second-factor");
        this.route("second-factor-backup");
      });

      this.route(
        "userInvited",
        { path: "/invited", resetNamespace: true },
        function () {
          this.route("show", { path: "/:filter" });
        }
      );
    }
  );

  this.route("review", { path: "/review" }, function () {
    this.route("show", { path: "/:reviewable_id" });
    this.route("index", { path: "/" });
    this.route("topics", { path: "/topics" });
    this.route("settings", { path: "/settings" });
  });
  this.route("signup", { path: "/signup" });
  this.route("login", { path: "/login" });
  this.route("email-login", { path: "/session/email-login/:token" });
  this.route("second-factor-auth", { path: "/session/2fa" });
  this.route("associate-account", { path: "/associate/:token" });
  this.route("login-preferences");
  this.route("forgot-password", { path: "/password-reset" });

  this.route("faq", { path: "/faq" });
  this.route("guidelines", { path: "/guidelines" });
  this.route("conduct", { path: "/conduct" });
  this.route("rules", { path: "/rules" });

  this.route("tos", { path: "/tos" });
  this.route("privacy", { path: "/privacy" });

  this.route("new-topic", { path: "/new-topic" });
  this.route("new-message", { path: "/new-message" });

  this.route("badges", { resetNamespace: true }, function () {
    this.route("show", { path: "/:id/:slug" });
  });

  this.route("full-page-search", { path: "/search" });

  this.route("tag", { resetNamespace: true }, function () {
    this.route("show", { path: "/:tag_id" });

    Site.currentProp("filters").forEach((filter) => {
      this.route("show" + capitalize(filter), {
        path: "/:tag_id/l/" + filter,
      });
    });
  });

  this.route("tags", { resetNamespace: true }, function () {
    this.route("showCategory", {
      path: "/c/*category_slug_path_with_id/:tag_id",
    });
    this.route("showCategoryAll", {
      path: "/c/*category_slug_path_with_id/all/:tag_id",
    });
    this.route("showCategoryNone", {
      path: "/c/*category_slug_path_with_id/none/:tag_id",
    });

    Site.currentProp("filters").forEach((filter) => {
      this.route("showCategory" + capitalize(filter), {
        path: "/c/*category_slug_path_with_id/:tag_id/l/" + filter,
      });
      this.route("showCategoryAll" + capitalize(filter), {
        path: "/c/*category_slug_path_with_id/all/:tag_id/l/" + filter,
      });
      this.route("showCategoryNone" + capitalize(filter), {
        path: "/c/*category_slug_path_with_id/none/:tag_id/l/" + filter,
      });
    });
    this.route("intersection", {
      path: "intersection/:tag_id/*additional_tags",
    });

    // legacy route
    this.route("legacyRedirect", { path: "/:tag_id" });
  });

  this.route(
    "tagGroups",
    { path: "/tag_groups", resetNamespace: true },
    function () {
      this.route("edit", { path: "/:id" });
      this.route("new");
    }
  );

  this.route(
    "invites",
    { path: "/invites", resetNamespace: true },
    function () {
      this.route("show", { path: "/:token" });
    }
  );
}
