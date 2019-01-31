import { wantsNewWindow } from "discourse/lib/intercept-click";
import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import DiscourseURL from "discourse/lib/url";

export default createWidget("link", {
  tagName: "a",

  href(attrs) {
    const route = attrs.route;
    if (route) {
      const router = this.register.lookup("router:main");
      if (router && router._routerMicrolib) {
        const params = [route];
        if (attrs.model) {
          params.push(attrs.model);
        }
        return Discourse.getURL(
          router._routerMicrolib.generate.apply(router._routerMicrolib, params)
        );
      }
    } else {
      return Discourse.getURL(attrs.href);
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
        ? I18n.t(attrs.title, attrs.titleOptions)
        : this.label(attrs)
    };
    if (attrs.attributes) {
      Object.keys(attrs.attributes).forEach(
        k => (ret[k] = attrs.attributes[k])
      );
    }
    return ret;
  },

  label(attrs) {
    if (attrs.labelCount && attrs.count) {
      return I18n.t(attrs.labelCount, { count: attrs.count });
    }
    return attrs.rawLabel || (attrs.label ? I18n.t(attrs.label) : "");
  },

  html(attrs) {
    if (attrs.contents) {
      return attrs.contents();
    }

    const result = [];
    if (attrs.icon) {
      result.push(iconNode(attrs.icon));
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
      const val = parseInt(currentUser.get(attrs.badgeCount));
      if (val > 0) {
        const title = attrs.badgeTitle ? I18n.t(attrs.badgeTitle) : "";
        result.push(" ");
        result.push(
          h(
            "span.badge-notification",
            {
              className: attrs.badgeClass,
              attributes: { title }
            },
            val
          )
        );
      }
    }

    return result;
  },

  click(e) {
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

    return DiscourseURL.routeToTag($(e.target).closest("a")[0]);
  }
});
