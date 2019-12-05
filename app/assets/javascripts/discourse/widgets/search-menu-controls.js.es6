import { get } from "@ember/object";
import { searchContextDescription } from "discourse/lib/search";
import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

createWidget("search-term", {
  tagName: "input",
  buildId: () => "search-term",
  buildKey: () => `search-term`,

  defaultState() {
    return { afterAutocomplete: false };
  },

  searchAutocompleteAfterComplete() {
    this.state.afterAutocomplete = true;
  },

  buildAttributes(attrs) {
    return {
      type: "text",
      value: attrs.value || "",
      autocomplete: "discourse",
      placeholder: attrs.contextEnabled ? "" : I18n.t("search.title")
    };
  },

  keyUp(e) {
    if (e.which === 13) {
      if (this.state.afterAutocomplete) {
        this.state.afterAutocomplete = false;
      } else {
        return this.sendWidgetAction("fullSearch");
      }
    }

    const val = this.attrs.value;
    const newVal = $(`#${this.buildId()}`).val();

    if (newVal !== val) {
      this.sendWidgetAction("searchTermChanged", newVal);
    }
  }
});

createWidget("search-context", {
  tagName: "div.search-context",

  html(attrs) {
    const service = this.register.lookup("search-service:main");
    const ctx = service.get("searchContext");

    const result = [];
    if (ctx) {
      const description = searchContextDescription(
        get(ctx, "type"),
        get(ctx, "user.username") ||
          get(ctx, "category.name") ||
          get(ctx, "tag.id")
      );
      result.push(
        h("label", [
          h("input", { type: "checkbox", checked: attrs.contextEnabled }),
          " ",
          description
        ])
      );
    }

    if (!attrs.contextEnabled) {
      result.push(
        this.attach("link", {
          href: attrs.url,
          label: "show_help",
          className: "show-help"
        })
      );
    }

    result.push(h("div.clearfix"));
    return result;
  },

  click() {
    const val = $(".search-context input").is(":checked");
    if (val !== this.attrs.contextEnabled) {
      this.sendWidgetAction("searchContextChanged", val);
    }
  }
});
