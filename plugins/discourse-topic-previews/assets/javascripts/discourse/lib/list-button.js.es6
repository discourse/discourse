export default function buttonHTML(action) {
  action = action || {};

  var html = "<button class='list-button " + action.class + "'";
  if (action.title) { html += 'title="' + I18n.t(action.title) + '"'; }
  if (action.disabled) {html += ' disabled';}
  html += "><i class='fa fa-" + action.icon + "' aria-hidden='true'></i>";
  html += "</button>";
  return html;
}
