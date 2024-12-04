import { hbs } from "ember-cli-htmlbars";
import { h } from "virtual-dom";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { formatUsername } from "discourse/lib/utilities";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { applyDecorators, createWidget } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import { iconNode } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

let sanitizeName = function (name) {
  return name.toLowerCase().replace(/[\s\._-]/g, "");
};

export function disableNameSuppression() {
  sanitizeName = (name) => name;
}

createWidget("poster-name-title", {
  tagName: "span.user-title",

  buildClasses(attrs) {
    let classNames = [];

    classNames.push(attrs.title);

    if (attrs.titleIsGroup) {
      classNames.push(attrs.primaryGroupName);
    }

    classNames = classNames.map(
      (className) =>
        `user-title--${className.replace(/\s+/g, "-").toLowerCase()}`
    );

    return classNames;
  },

  html(attrs) {
    let titleContents = attrs.title;
    if (attrs.primaryGroupName && attrs.titleIsGroup) {
      const href = getURL(`/g/${attrs.primaryGroupName}`);
      titleContents = h(
        "a.user-group",
        {
          className: attrs.extraClasses,
          attributes: { href, "data-group-card": attrs.primaryGroupName },
        },
        attrs.title
      );
    }
    return titleContents;
  },
});

export default createWidget("poster-name", {
  tagName: "div.names.trigger-user-card",

  settings: {
    showNameAndGroup: true,
    showGlyph: true,
  },

  didRenderWidget() {
    if (this.attrs.user) {
      this.attrs.user.statusManager.trackStatus();
      this.attrs.user.on("status-changed", this, "scheduleRerender");
    }
  },

  willRerenderWidget() {
    if (this.attrs.user) {
      this.attrs.user.off("status-changed", this, "scheduleRerender");
      this.attrs.user.statusManager.stopTrackingStatus();
    }
  },

  // TODO: Allow extensibility
  posterGlyph(attrs) {
    if (attrs.moderator || attrs.groupModerator) {
      return iconNode("shield-halved", {
        title: i18n("user.moderator_tooltip"),
      });
    }
  },

  userLink(attrs, text) {
    return h(
      "a",
      {
        attributes: {
          href: attrs.usernameUrl,
          "data-user-card": attrs.username,
          class: `${
            this.siteSettings.hide_user_profiles_from_public &&
            !this.currentUser
              ? "non-clickable"
              : ""
          }`,
        },
      },
      formatUsername(text)
    );
  },

  html(attrs) {
    const username = attrs.username;
    const name = attrs.name;
    const nameFirst =
      this.siteSettings.display_name_on_posts && prioritizeNameInUx(name);
    const classNames = nameFirst
      ? ["first", "full-name"]
      : ["first", "username"];

    if (attrs.staff) {
      classNames.push("staff");
    }
    if (attrs.admin) {
      classNames.push("admin");
    }
    if (attrs.moderator) {
      classNames.push("moderator");
    }
    if (attrs.groupModerator) {
      classNames.push("category-moderator");
    }
    if (attrs.new_user) {
      classNames.push("new-user");
    }

    const primaryGroupName = attrs.primary_group_name;
    if (primaryGroupName && primaryGroupName.length) {
      classNames.push(`group--${primaryGroupName}`);
    }
    let nameContents = [this.userLink(attrs, nameFirst ? name : username)];

    if (this.settings.showGlyph) {
      const glyph = this.posterGlyph(attrs);
      if (glyph) {
        nameContents.push(glyph);
      }
    }

    const afterNameContents =
      applyDecorators(this, "after-name", attrs, this.state) || [];

    nameContents = nameContents.concat(afterNameContents);

    const contents = [
      h("span", { className: classNames.join(" ") }, nameContents),
    ];

    if (this.settings.showNameAndGroup) {
      if (
        name &&
        this.siteSettings.display_name_on_posts &&
        sanitizeName(name) !== sanitizeName(username)
      ) {
        contents.push(
          h(
            "span.second." + (nameFirst ? "username" : "full-name"),
            [this.userLink(attrs, nameFirst ? username : name)].concat(
              afterNameContents
            )
          )
        );
      }

      this.buildTitleObject(attrs, contents);

      if (this.siteSettings.enable_user_status) {
        this.addUserStatus(contents, attrs);
      }
    }

    if (attrs.badgesGranted?.length) {
      const badges = [];

      attrs.badgesGranted.forEach((badge) => {
        // Alter the badge description to show that the badge was granted for this post.
        badge.description = i18n("post.badge_granted_tooltip", {
          username: attrs.username,
          badge_name: badge.name,
        });

        const badgeIcon = new RenderGlimmer(
          this,
          `span.user-badge-button-${badge.slug}`,
          hbs`<UserBadge @badge={{@data.badge}} @user={{@data.user}} @showName={{false}} />`,
          {
            badge,
            user: attrs.user,
          }
        );
        badges.push(badgeIcon);
      });

      contents.push(h("span.user-badge-buttons", badges));
    }

    return contents;
  },

  buildTitleObject(attrs, contents) {
    const primaryGroupName = attrs.primary_group_name;
    const title = attrs.user_title,
      titleIsGroup = attrs.title_is_group;

    if (title && title.length) {
      contents.push(
        this.attach("poster-name-title", {
          title,
          primaryGroupName,
          titleIsGroup,
        })
      );
    }
  },

  addUserStatus(contents, attrs) {
    if (attrs.user && attrs.user.status) {
      contents.push(this.attach("post-user-status", attrs.user.status));
    }
  },
});
