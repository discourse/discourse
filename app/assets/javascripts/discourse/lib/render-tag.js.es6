export default function renderTag(tag, params) {
  params = params || {};
  tag = Handlebars.Utils.escapeExpression(tag);
  const classes = ['tag-' + tag, 'discourse-tag'];
  const tagName = params.tagName || "a";
  let path;
  if (tagName === "a" && !params.noHref) {
    const current_user = Discourse.User.current();
    path = params.isPrivateMessage ? `/u/${current_user.username}/messages/tag/${tag}` : `/tags/${tag}`;
  }
  const href = path ? ` href='${Discourse.getURL(path)}' ` : "";

  if (Discourse.SiteSettings.tag_style || params.style) {
    classes.push(params.style || Discourse.SiteSettings.tag_style);
  }

  let val = "<" + tagName + href + " class='" + classes.join(" ") + "'>" + tag + "</" + tagName + ">";

  if (params.count) {
    val += " <span class='discourse-tag-count'>x" + params.count + "</span>";
  }

  return val;
};
