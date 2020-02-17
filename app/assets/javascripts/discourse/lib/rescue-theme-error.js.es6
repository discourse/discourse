import { ajax } from "discourse/lib/ajax";

function reportToLogster(name, error) {
  const data = {
    message: `${name} theme/component is throwing errors`,
    stacktrace: error.stack
  };

  ajax("/logs/report_js_error", {
    data,
    type: "POST",
    cache: false
  });
}

// this function is used in lib/theme_javascript_compiler.rb
export default function rescueThemeError(name, error, api) {
  /* eslint-disable-next-line no-console */
  console.error(`"${name}" error:`, error);
  reportToLogster(name, error);

  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.admin) {
    return;
  }

  const path = `${Discourse.BaseUri}/admin/customize/themes`;
  const message = I18n.t("themes.broken_theme_alert", {
    theme: name,
    path: `<a href="${path}">${path}</a>`
  });
  const alertDiv = document.createElement("div");
  alertDiv.classList.add("broken-theme-alert");
  alertDiv.innerHTML = `⚠️ ${message}`;
  document.body.prepend(alertDiv);
}
