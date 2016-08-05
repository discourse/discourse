import { htmlHelper } from 'discourse/lib/helpers';

function renderSpinner(cssClass) {
  var html = "<div class='spinner";
  if (cssClass) { html += ' ' + cssClass; }
  return html + "'></div>";
}
var spinnerHTML = renderSpinner();

export default htmlHelper(params => {
  const hash = params.hash;
  return renderSpinner((hash && hash.size) ? hash.size : undefined);
});

export { spinnerHTML, renderSpinner };
