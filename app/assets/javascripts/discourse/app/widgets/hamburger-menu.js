import DiscourseURL, { userPath } from "discourse/lib/url";
import { applyDecorators, createWidget } from "discourse/widgets/widget";
import I18n from "I18n";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import { later } from "@ember/runloop";
import { wantsNewWindow } from "discourse/lib/intercept-click";

const flatten = (array) => [].concat.apply([], array);

createWidget("priority-faq-link", {
  tagName: "a.faq-priority.widget-link",

  buildAttributes(attrs) {
    return { href: attrs.href };
  },

  html() {
    return [
      I18n.t("faq"),
      " ",
      h("span.badge.badge-notification", I18n.t("new_item")),
    ];
  },

  click(e) {
    const {
      attrs: { href },
      currentUser,
      siteSettings,
    } = this;

    if (siteSettings.faq_url === href) {
      ajax(userPath("read-faq"), { type: "POST" }).then(() => {
        currentUser.set("read_faq", true);

        if (wantsNewWindow(e)) {
          return;
        }

        e.preventDefault();
        DiscourseURL.routeTo(href);
      });
    } else {
      if (wantsNewWindow(e)) {
        return;
      }

      e.preventDefault();
      DiscourseURL.routeTo(href);
    }
  },
});

export default createWidget("hamburger-menu", {
  buildKey: () => "hamburger-menu",

  tagName: "div.hamburger-panel",

  settings: {
    showCategories: true,
    maxWidth: 320,
    showFAQ: true,
    showAbout: true,
  },

  defaultState() {
    return { loaded: false, loading: false };
  },

  adminLinks() {
    const { currentUser } = this;

    const links = [
      {
        route: "admin",
        className: "admin-link",
        icon: "wrench",
        label: "admin_title",
      },
    ];

    if (currentUser.admin) {
      links.push({
        href: "/admin/site_settings",
        icon: "cog",
        label: "admin.site_settings.title",
        className: "settings-link",
      });
    }

    return links.map((l) => this.attach("link", l));
  },

  lookupCount(type) {
    const tts = this.register.lookup("topic-tracking-state:main");
    return tts ? tts.lookupCount(type) : 0;
  },

  generalLinks() {
    const { attrs, currentUser, siteSettings, state } = this;
    const links = [];

    links.push({
      route: "discovery.latest",
      className: "latest-topics-link",
      label: "filters.latest.title",
      title: "filters.latest.help",
    });

    if (currentUser) {
      links.push({
        route: "discovery.new",
        className: "new-topics-link",
        labelCount: "filters.new.title_with_count",
        label: "filters.new.title",
        title: "filters.new.help",
        count: this.lookupCount("new"),
      });

      links.push({
        route: "discovery.unread",
        className: "unread-topics-link",
        labelCount: "filters.unread.title_with_count",
        label: "filters.unread.title",
        title: "filters.unread.help",
        count: this.lookupCount("unread"),
      });

      if (currentUser.can_review) {
        links.push({
          route: siteSettings.reviewable_default_topics
            ? "review.topics"
            : "review",
          className: "review",
          label: "review.title",
          badgeCount: "reviewable_count",
          badgeClass: "reviewables",
        });
      }
    }

    links.push({
      route: "discovery.top",
      className: "top-topics-link",
      label: "filters.top.title",
      title: "filters.top.help",
    });

    if (siteSettings.enable_badges) {
      links.push({
        route: "badges",
        className: "badge-link",
        label: "badges.title",
      });
    }

    const canSeeUserProfiles =
      currentUser || !siteSettings.hide_user_profiles_from_public;
    if (siteSettings.enable_user_directory && canSeeUserProfiles) {
      links.push({
        route: "users",
        className: "user-directory-link",
        label: "directory.title",
      });
    }

    if (siteSettings.enable_group_directory) {
      links.push({
        route: "groups",
        className: "groups-link",
        label: "groups.index.title",
      });
    }

    if (siteSettings.tagging_enabled) {
      links.push({ route: "tags", label: "tagging.tags" });
    }

    const extraLinks = flatten(
      applyDecorators(this, "generalLinks", attrs, state)
    );

    return links.concat(extraLinks).map((l) => this.attach("link", l));
  },

  listCategories() {
    const { currentUser, site, siteSettings } = this;
    const maxCategoriesToDisplay = siteSettings.header_dropdown_category_count;

    let categories = [];

    if (currentUser) {
      const allCategories = site
        .get("categories")
        .filter((c) => c.notification_level !== NotificationLevels.MUTED);

      categories = allCategories
        .filter((c) => c.get("newTopics") > 0 || c.get("unreadTopics") > 0)
        .sort((a, b) => {
          return (
            b.get("newTopics") +
            b.get("unreadTopics") -
            (a.get("newTopics") + a.get("unreadTopics"))
          );
        });

      const topCategoryIds = currentUser.get("top_category_ids") || [];

      topCategoryIds.forEach((id) => {
        const category = allCategories.find((c) => c.id === id);
        if (category && !categories.includes(category)) {
          categories.push(category);
        }
      });

      categories = categories.concat(
        allCategories
          .filter((c) => !categories.includes(c))
          .sort((a, b) => b.topic_count - a.topic_count)
      );
    } else {
      categories = site
        .get("categoriesByCount")
        .filter((c) => c.notification_level !== NotificationLevels.MUTED);
    }

    if (!siteSettings.allow_uncategorized_topics) {
      categories = categories.filter(
        (c) => c.id !== site.uncategorized_category_id
      );
    }

    const moreCount = categories.length - maxCategoriesToDisplay;
    categories = categories.slice(0, maxCategoriesToDisplay);

    return this.attach("hamburger-categories", { categories, moreCount });
  },

  footerLinks(prioritizeFaq, faqUrl) {
    const { attrs, capabilities, settings, site, siteSettings, state } = this;
    const links = [];

    if (settings.showAbout) {
      links.push({
        route: "about",
        className: "about-link",
        label: "about.simple_title",
      });
    }

    if (settings.showFAQ && !prioritizeFaq) {
      links.push({ href: faqUrl, className: "faq-link", label: "faq" });
    }

    if (!site.mobileView && !capabilities.touch) {
      links.push({
        href: "",
        action: "showKeyboard",
        className: "keyboard-shortcuts-link",
        label: "keyboard_shortcuts_help.title",
      });
    }

    const mobileTouch = siteSettings.enable_mobile_theme && capabilities.touch;
    if (site.mobileView || mobileTouch) {
      links.push({
        action: "toggleMobileView",
        className: "mobile-toggle-link",
        label: site.mobileView ? "desktop_view" : "mobile_view",
      });
    }

    const extraLinks = flatten(
      applyDecorators(this, "footerLinks", attrs, state)
    );

    return links.concat(extraLinks).map((l) => this.attach("link", l));
  },

  panelContents() {
    const { attrs, currentUser, settings, siteSettings, state } = this;
    const results = [];
    const faqUrl = siteSettings.faq_url || getURL("/faq");
    const prioritizeFaq =
      settings.showFAQ && currentUser && !currentUser.read_faq;

    if (prioritizeFaq) {
      results.push(
        this.attach("menu-links", {
          name: "faq-link",
          heading: true,
          contents: () => {
            return this.attach("priority-faq-link", { href: faqUrl });
          },
        })
      );
    }

    if (currentUser && currentUser.staff) {
      results.push(
        this.attach("menu-links", {
          name: "admin-links",
          contents: () => {
            const extraLinks = flatten(
              applyDecorators(this, "admin-links", attrs, state)
            );
            return this.adminLinks().concat(extraLinks);
          },
        })
      );
    }

    results.push(
      this.attach("menu-links", {
        name: "general-links",
        contents: () => this.generalLinks(),
      })
    );

    if (settings.showCategories) {
      results.push(this.listCategories());
      results.push(h("hr.categories-separator"));
    }

    results.push(
      this.attach("menu-links", {
        name: "footer-links",
        omitRule: true,
        contents: () => this.footerLinks(prioritizeFaq, faqUrl),
      })
    );

    return results;
  },

  refreshReviewableCount(state) {
    const { currentUser } = this;

    if (state.loading || !currentUser || !currentUser.can_review) {
      return;
    }

    state.loading = true;

    return ajax("/review/count.json")
      .then(({ count }) => currentUser.set("reviewable_count", count))
      .finally(() => {
        state.loaded = true;
        state.loading = false;
        this.scheduleRerender();
      });
  },

  html(attrs, state) {
    if (!state.loaded) {
      this.refreshReviewableCount(state);
    }

    return this.attach("menu-panel", {
      contents: () => this.panelContents(),
      maxWidth: this.settings.maxWidth,
    });
  },

  clickOutsideMobile(e) {
    const centeredElement = document.elementFromPoint(e.clientX, e.clientY);
    const parents = document
      .elementsFromPoint(e.clientX, e.clientY)
      .some((ele) => ele.classList.contains("panel"));
    if (!centeredElement.classList.contains("header-cloak") && parents) {
      this.sendWidgetAction("toggleHamburger");
    } else {
      const windowWidth = document.body.offsetWidth;
      const panel = document.querySelector(".menu-panel");
      panel.classList.add("animate");
      let offsetDirection = this.site.mobileView ? -1 : 1;
      offsetDirection =
        document.querySelector("html").classList["direction"] === "rtl"
          ? -offsetDirection
          : offsetDirection;
      panel.style.setProperty("--offset", `${offsetDirection * windowWidth}px`);
      const headerCloak = document.querySelector(".header-cloak");
      headerCloak.classList.add("animate");
      headerCloak.style.setProperty("--opacity", 0);
      later(() => this.sendWidgetAction("toggleHamburger"), 200);
    }
  },

  clickOutside(e) {
    if (this.site.mobileView) {
      this.clickOutsideMobile(e);
    } else {
      this.sendWidgetAction("toggleHamburger");
    }
  },
});
