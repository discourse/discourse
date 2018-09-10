import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

createWidget("menu-links", {
  buildClasses(attrs) {
    if (attrs.name && attrs.name.length) {
      return `menu-container-${attrs.name}`;
    }
  },

  html(attrs) {
    const links = [].concat(attrs.contents());
    const liOpts = {};

    if (attrs.heading) {
      liOpts.className = "header";
    }

    const result = [];
    result.push(
      h("ul.menu-links.columned", links.map(l => h("li", liOpts, l)))
    );

    result.push(h("div.clearfix"));
    if (!attrs.omitRule) {
      result.push(h("hr"));
    }
    return result;
  }
});

createWidget("menu-panel", {
  tagName: "div.menu-panel",
  template: hbs`
    <div class='panel-body'>
      <div class='panel-body-contents clearfix'>
        {{yield}}
      </div>
    </div>
  `,

  buildAttributes(attrs) {
    if (attrs.maxWidth) {
      return { "data-max-width": attrs.maxWidth };
    }
  }
});
