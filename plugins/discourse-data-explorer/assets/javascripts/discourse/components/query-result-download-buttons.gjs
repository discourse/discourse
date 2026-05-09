import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { QUERY_RESULT_MAX_LIMIT } from "discourse/plugins/discourse-data-explorer/discourse/lib/constants";

export default class QueryResultDownloadButtons extends Component {
  get params() {
    return this.args.content.params;
  }

  get explainText() {
    return this.args.content.explain;
  }

  @action
  downloadResultJson() {
    this._downloadResult("json");
  }

  @action
  downloadResultCsv() {
    this._downloadResult("csv");
  }

  _downloadUrl() {
    return this.args.group
      ? `/g/${this.args.group.name}/reports/`
      : "/admin/plugins/discourse-data-explorer/queries/";
  }

  _downloadResult(format) {
    const windowName = randomIdShort();
    const newWindowContents =
      "<style>body{font-size:36px;display:flex;justify-content:center;align-items:center;}</style><body>Click anywhere to close this window once the download finishes.<script>window.onclick=function(){window.close()};</script>";

    window.open("data:text/html;base64," + btoa(newWindowContents), windowName);

    let form = document.createElement("form");
    form.setAttribute("id", "query-download-result");
    form.setAttribute("method", "post");
    form.setAttribute(
      "action",
      getURL(
        this._downloadUrl() +
          this.args.query.id +
          "/run." +
          format +
          "?download=1"
      )
    );
    form.setAttribute("target", windowName);
    form.setAttribute("style", "display:none;");

    function addInput(name, value) {
      let field;
      field = document.createElement("input");
      field.setAttribute("name", name);
      field.setAttribute("value", value);
      form.appendChild(field);
    }

    addInput("params", JSON.stringify(this.params));
    addInput("explain", this.explainText);
    addInput("limit", String(QUERY_RESULT_MAX_LIMIT));

    ajax("/session/csrf.json").then((csrf) => {
      addInput("authenticity_token", csrf.csrf);

      document.body.appendChild(form);
      form.submit();
      schedule("afterRender", () => document.body.removeChild(form));
    });
  }

  <template>
    <div class="query-result-download-buttons" ...attributes>
      <DButton
        @action={{this.downloadResultJson}}
        @icon="download"
        @label="explorer.download_json"
      />

      <DButton
        @action={{this.downloadResultCsv}}
        @icon="download"
        @label="explorer.download_csv"
      />
    </div>
  </template>
}

function randomIdShort() {
  return "xxxxxxxx".replace(/[xy]/g, () => {
    /*eslint-disable*/
    return ((Math.random() * 16) | 0).toString(16);
    /*eslint-enable*/
  });
}
