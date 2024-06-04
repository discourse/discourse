import RestAdapter from "discourse/adapters/rest";

export default class WebHookEvent extends RestAdapter {
  basePath() {
    return "/admin/api/";
  }

  appendQueryParams(path, findArgs, extension) {
    const urlSearchParams = new URLSearchParams();

    for (const [key, value] of Object.entries(findArgs)) {
      if (value && key !== "webhookId") {
        urlSearchParams.set(key, value);
      }
    }

    const queryString = urlSearchParams.toString();

    if (queryString) {
      return `${path}/${findArgs.webhookId}${extension || ""}?${queryString}`;
    }
    return `${path}/${findArgs.webhookId}${extension || ""}`;
  }
}
