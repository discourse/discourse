import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { QUERY_RESULT_MAX_LIMIT } from "discourse/plugins/discourse-data-explorer/discourse/lib/constants";

export default class QueryResultDownloadButtons extends Component {
  get hasResults() {
    return !!this.args.content?.rows?.length;
  }

  get params() {
    return this.args.content?.params;
  }

  get explainText() {
    return this.args.content?.explain;
  }

  @action
  downloadQueryJson(dMenu) {
    window.open(this.args.query.downloadUrl, "_blank");
    dMenu?.close();
  }

  @action
  downloadResultJson(dMenu) {
    this._downloadResult("json");
    dMenu?.close();
  }

  @action
  downloadResultCsv(dMenu) {
    this._downloadResult("csv");
    dMenu?.close();
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
    <DMenu
      @identifier="query-result-export"
      @triggerClass="btn-default query-result-export__trigger query-result-download-buttons"
      @placement="bottom-end"
      ...attributes
    >
      <:trigger>
        {{dIcon "download"}}
        <span>{{i18n "explorer.export_as.label"}}</span>
        {{dIcon "angle-down"}}
      </:trigger>
      <:content as |dMenu|>
        <DDropdownMenu as |dropdown|>
          {{#if this.hasResults}}
            <dropdown.item>
              <DButton
                @action={{fn this.downloadResultJson dMenu}}
                @label="explorer.export_as.results_json"
                class="btn-transparent query-result-export__results-json"
              />
            </dropdown.item>
            <dropdown.item>
              <DButton
                @action={{fn this.downloadResultCsv dMenu}}
                @label="explorer.export_as.results_csv"
                class="btn-transparent query-result-export__results-csv"
              />
            </dropdown.item>
          {{/if}}
          {{#if @includeQueryExport}}
            <dropdown.item>
              <DButton
                @action={{fn this.downloadQueryJson dMenu}}
                @label="explorer.export_as.query_json"
                class="btn-transparent query-result-export__query-json"
              />
            </dropdown.item>
          {{/if}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}

function randomIdShort() {
  return "xxxxxxxx".replace(/[xy]/g, () => {
    /*eslint-disable*/
    return ((Math.random() * 16) | 0).toString(16);
    /*eslint-enable*/
  });
}
