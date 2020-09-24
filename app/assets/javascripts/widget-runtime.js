// discourse-skip-module

(function (context) {
  // register widget helpers for compiled `hbs`
  context.__widget_helpers = {
    avatar: require("discourse/widgets/post").avatarFor,
    dateNode: require("discourse/helpers/node").dateNode,
    iconNode: require("discourse-common/lib/icon-library").iconNode,
    rawHtml: require("discourse/widgets/raw-html").default,
  };
})(this);
