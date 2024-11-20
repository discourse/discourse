import { h } from "virtual-dom";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DiscourseURL from "discourse/lib/url";
import { createWidget } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import { iconNode } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

export default createWidget("link", {
  tagName: "a",

  href(attrs) {
    if (attrs.route) {
      const router = this.register.lookup("service:router");

      if (attrs.model) {
        return router.urlFor(attrs.route, attrs.model);
      } else {
        return router.urlFor(attrs.route);
      }
    } else {
      return getURL(attrs.href);
    }
  },

  buildClasses(attrs) {
    const result = [];
    result.push("widget-link");
    if (attrs.className) {
      result.push(attrs.className);
    }
    return result;
  },

  buildAttributes(attrs) {
    const ret = {
      href: this.href(attrs),
      title: attrs.title
        ? i18n(attrs.title, attrs.titleOptions)
        : this.label(attrs),
    };
    if (attrs.attributes) {
      Object.keys(attrs.attributes).forEach(
        (k) => (ret[k] = attrs.attributes[k])
      );
    }
    return ret;
  },

  label(attrs) {
    if (attrs.labelCount && attrs.count) {
      return i18n(attrs.labelCount, { count: attrs.count });
    }
    return attrs.rawLabel || (attrs.label ? i18n(attrs.label) : "");
  },

  html(attrs) {
    if (attrs.contents) {
      return attrs.contents();
    }

    const result = [];
    if (attrs.icon) {
      if (attrs["aria-label"]) {
        let icon = iconNode(attrs.icon);

        icon.properties.attributes["aria-label"] = i18n(
          attrs["aria-label"],
          attrs.ariaLabelOptions
        );

        icon.properties.attributes["role"] = "img";
        icon.properties.attributes["aria-hidden"] = false;
        result.push(icon);
      } else {
        result.push(iconNode(attrs.icon));
      }
      result.push(" ");
    }

    if (!attrs.hideLabel) {
      let label = this.label(attrs);

      if (attrs.omitSpan) {
        result.push(label);
      } else {
        result.push(h("span.d-label", label));
      }
    }

    const currentUser = this.currentUser;
    if (currentUser && attrs.badgeCount) {
      const val = parseInt(currentUser.get(attrs.badgeCount), 10);
      if (val > 0) {
        const title = attrs.badgeTitle ? i18n(attrs.badgeTitle) : "";
        result.push(" ");
        result.push(
          h(
            "span.badge-notification",
            {
              className: attrs.badgeClass,
              attributes: { title },
            },
            val
          )
        );
      }
    }
    return result;
  },

  click(e) {
    if (this.attrs.attributes && this.attrs.attributes.target === "_blank") {
      return;
    }

    if (wantsNewWindow(e)) {
      return;
    }

    e.preventDefault();

    if (this.attrs.action) {
      e.preventDefault();
      return this.sendWidgetAction(this.attrs.action, this.attrs.actionParam);
    } else {
      this.sendWidgetEvent("linkClicked", this.attrs);
    }

    return DiscourseURL.routeToTag(e.target.closest("a"));
  },
});
