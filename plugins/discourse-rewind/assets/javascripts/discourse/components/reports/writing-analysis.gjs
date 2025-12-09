import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import number from "discourse/helpers/number";
import { i18n } from "discourse-i18n";

export default class WritingAnalysis extends Component {
  @service rewind;

  @tracked currentColorIndex = 0;

  terminalColors = ["#0f0", "#ffbf00", "#00ffff", "#ff00ff"];

  constructor() {
    super(...arguments);
    this.handleKeyDown = this.handleKeyDown.bind(this);
  }

  @action
  setupKeyListener(element) {
    document.addEventListener("keydown", this.handleKeyDown);
    this.element = element;
  }

  @action
  teardownKeyListener() {
    document.removeEventListener("keydown", this.handleKeyDown);
  }

  handleKeyDown(event) {
    if (event.key === "F1") {
      event.preventDefault();
      this.cycleColor();
    }
  }

  @action
  cycleColor() {
    this.currentColorIndex =
      (this.currentColorIndex + 1) % this.terminalColors.length;
    const newColor = this.terminalColors[this.currentColorIndex];
    document.documentElement.style.setProperty("--rewind-green", newColor);
  }

  get scoreLabel() {
    const score = this.args.report.data.readability_score;
    const randomNum = Math.floor(Math.random() * 4) + 1;

    switch (true) {
      case score >= 80 && score <= 100:
        return i18n(
          `discourse_rewind.reports.writing_analysis.readability_score.over_80.${randomNum}`
        );
      case score >= 60 && score < 80:
        return i18n(
          `discourse_rewind.reports.writing_analysis.readability_score.over_60.${randomNum}`
        );
      case score >= 40 && score < 60:
        return i18n(
          `discourse_rewind.reports.writing_analysis.readability_score.over_40.${randomNum}`
        );
      case score >= 20 && score < 40:
        return i18n(
          `discourse_rewind.reports.writing_analysis.readability_score.over_20.${randomNum}`
        );
      default:
        return i18n(
          `discourse_rewind.reports.writing_analysis.readability_score.over_0.${randomNum}`
        );
    }
  }

  get minimumDataThresholdMet() {
    return (
      this.args.report.data.total_words >= 100 &&
      this.args.report.data.total_posts >= 5
    );
  }

  <template>
    {{#if this.minimumDataThresholdMet}}
      <div
        class="rewind-report-page --writing-analysis"
        {{didInsert this.setupKeyListener}}
        {{willDestroy this.teardownKeyListener}}
      >
        <h2 class="rewind-report-title">
          {{i18n "discourse_rewind.reports.writing_analysis.title"}}
        </h2>

        <div class="writing-analysis">

          <div class="writing-analysis__menubar">
            <span class="writing-analysis__menu-item">{{i18n
                "discourse_rewind.reports.writing_analysis.menu_file"
              }}</span>
            <span class="writing-analysis__menu-item">{{i18n
                "discourse_rewind.reports.writing_analysis.menu_other"
              }}</span>
            <span class="writing-analysis__menu-item">{{i18n
                "discourse_rewind.reports.writing_analysis.menu_additional"
              }}</span>
            <span
              class="writing-analysis__menu-item writing-analysis__menu-item--right"
            >{{i18n
                "discourse_rewind.reports.writing_analysis.menu_opening"
              }}</span>
          </div>

          <div class="writing-analysis__frame">

            <div class="writing-analysis__header-row">

              <div class="writing-analysis__helpbox">
                {{i18n "discourse_rewind.reports.writing_analysis.help_text"}}
              </div>

              <div class="writing-analysis__release">
                <div class="writing-analysis__release-name">{{i18n
                    "discourse_rewind.reports.writing_analysis.app_name"
                  }}</div>
                <div class="writing-analysis__release-meta">
                  {{i18n
                    "discourse_rewind.reports.writing_analysis.release_info"
                    rewindYear=this.rewind.fetchRewindYear
                  }}
                  <span>&lt;3</span>
                </div>
              </div>

            </div>

            <div class="writing-analysis__stats">

              <div class="writing-analysis__stats-col">
                <div class="writing-analysis__stats-label">{{i18n
                    "discourse_rewind.reports.writing_analysis.total_words"
                  }}</div>
                <div
                  class="writing-analysis__stats-value"
                >{{@report.data.total_words}}</div>

                <div class="writing-analysis__stats-label">{{i18n
                    "discourse_rewind.reports.writing_analysis.total_posts"
                  }}</div>
                <div
                  class="writing-analysis__stats-value"
                >{{@report.data.total_posts}}</div>
              </div>

              <div class="writing-analysis__stats-col">
                <div class="writing-analysis__stats-label">{{i18n
                    "discourse_rewind.reports.writing_analysis.avg_post_length"
                  }}</div>
                <div class="writing-analysis__stats-value">{{number
                    @report.data.average_post_length
                  }}</div>

                <div class="writing-analysis__stats-label">{{i18n
                    "discourse_rewind.reports.writing_analysis.readability_score_label"
                  }}</div>
                <div class="writing-analysis__stats-value">{{number
                    @report.data.readability_score
                  }}/100</div>
              </div>

              <div class="writing-analysis__stats-col">
                <div class="writing-analysis__stats-label">{{i18n
                    "discourse_rewind.reports.writing_analysis.readability_level"
                  }}</div>
                <div
                  class="writing-analysis__stats-value"
                >{{this.scoreLabel}}</div>
              </div>

            </div>

          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
