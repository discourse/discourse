import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "bookmark-menu-shim",
  "div.bookmark-menu-shim",
  hbs`<BookmarkMenu @bookmarkManager={{@data.bookmarkManager}} @buttonClasses="btn-flat" />`
);
