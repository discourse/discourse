import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import htmlClass from "discourse/helpers/html-class";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class WebArtifactComponent extends Component {
  @service siteSettings;

  @tracked expanded = false;
  @tracked showingArtifact = false;

  #popStateHandler;

  #keydownHandler;

  constructor() {
    super(...arguments);
    this.#popStateHandler = this.#handlePopState.bind(this);
    this.#keydownHandler = this.#handleKeydown.bind(this);
    window.addEventListener("popstate", this.#popStateHandler);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("keydown", this.#keydownHandler);
    window.removeEventListener("popstate", this.#popStateHandler);
  }

  #handleKeydown(event) {
    if (event.key === "Escape" || event.key === "Esc") {
      history.back();
    }
  }

  #handlePopState(event) {
    const state = event.state;
    this.expanded = state?.artifactId === this.args.artifactId;
    if (!this.expanded) {
      window.removeEventListener("keydown", this.#keydownHandler);
    }
  }

  get requireClickToRun() {
    if (this.showingArtifact) {
      return false;
    }

    if (this.siteSettings.web_artifact_security === "strict") {
      return true;
    }

    if (this.siteSettings.web_artifact_security === "hybrid") {
      const shouldAutorun =
        this.args.autorun === "true" ||
        this.args.autorun === true ||
        this.args.autorun === "1";

      return !shouldAutorun;
    }

    return this.siteSettings.web_artifact_security !== "lax";
  }

  get artifactUrl() {
    let url = getURL(`/w/${this.args.artifactId}`);

    if (this.args.artifactVersion) {
      url = `${url}/${this.args.artifactVersion}`;
    }
    return url;
  }

  @action
  showArtifact() {
    this.showingArtifact = true;
  }

  @action
  toggleView() {
    if (!this.expanded) {
      window.history.pushState(
        { artifactId: this.args.artifactId },
        "",
        window.location.href + "#artifact-fullscreen"
      );
      window.addEventListener("keydown", this.#keydownHandler);
    } else {
      history.back();
    }
    this.expanded = !this.expanded;
  }

  get wrapperClasses() {
    return `web-artifact__wrapper ${
      this.expanded ? "--expanded" : ""
    } ${this.seamless ? "--seamless" : ""}`;
  }

  @action
  setDataAttributes(element) {
    if (this.args.dataAttributes) {
      Object.entries(this.args.dataAttributes).forEach(([key, value]) => {
        element.setAttribute(key, value);
      });
    }
  }

  get heightStyle() {
    if (this.args.artifactHeight) {
      let height = parseInt(this.args.artifactHeight, 10);
      if (isNaN(height) || height <= 0) {
        height = 500;
      }

      if (height > 2000) {
        height = 2000;
      }

      return trustHTML(`height: ${height}px;`);
    }
  }

  get seamless() {
    return (
      this.args.seamless === "true" ||
      this.args.seamless === true ||
      this.args.seamless === "1"
    );
  }

  get showFooter() {
    return !this.seamless && !this.requireClickToRun;
  }

  <template>
    {{#if this.expanded}}
      {{htmlClass "web-artifact-expanded"}}
    {{/if}}
    <div class={{this.wrapperClasses}} style={{this.heightStyle}}>
      <div class="web-artifact__panel-wrapper">
        <div class="web-artifact__panel">
          <DButton
            class="btn-flat btn-icon-text"
            @icon="discourse-compress"
            @label={{i18n "web_artifact.collapse_view_label"}}
            @action={{this.toggleView}}
          />
        </div>
      </div>
      {{#if this.requireClickToRun}}
        <div class="web-artifact__click-to-run">
          <DButton
            class="btn btn-primary"
            @icon="play"
            @label={{i18n "web_artifact.click_to_run_label"}}
            @action={{this.showArtifact}}
          />
        </div>
      {{else}}
        <iframe
          title="Web Artifact"
          src={{this.artifactUrl}}
          width="100%"
          frameborder="0"
          {{didInsert this.setDataAttributes}}
        ></iframe>
      {{/if}}
      {{#if this.showFooter}}
        <div class="web-artifact__footer">
          <DButton
            class="btn-transparent btn-icon-text web-artifact__expand-button"
            @icon="discourse-expand"
            @label={{i18n "web_artifact.expand_view_label"}}
            @action={{this.toggleView}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
