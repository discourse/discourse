import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default class WritingAnalysis extends Component {
  @service rewind;

  @tracked currentColorIndex = 0;

  terminalColors = ["#0f0", "#ffbf00", "#00ffff", "#ff00ff"];

  keyListener = modifier(() => {
    document.addEventListener("keydown", this.handleKeyDown);
    return () => document.removeEventListener("keydown", this.handleKeyDown);
  });

  get scoreLabel() {
    const score = this.args.report.data.readability_score;
    const bucket = [80, 60, 40, 20].find((min) => score >= min) ?? 0;
    const randomNum = Math.floor(Math.random() * 4) + 1;

    return i18n(
      `discourse_rewind.reports.writing_analysis.readability_score.over_${bucket}.${randomNum}`
    );
  }

  @bind
  handleKeyDown(event) {
    if (event.key === "F1") {
      event.preventDefault();
      this.cycleColor();
    }
  }

  cycleColor() {
    this.currentColorIndex =
      (this.currentColorIndex + 1) % this.terminalColors.length;
    const newColor = this.terminalColors[this.currentColorIndex];
    document.documentElement.style.setProperty("--rewind-green", newColor);
  }

  <template>
    <div class="rewind-report-page --writing-analysis" {{this.keyListener}}>
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
              <div class="writing-analysis__stats-value">{{dNumber
                  @report.data.total_words
                }}</div>

              <div class="writing-analysis__stats-label">{{i18n
                  "discourse_rewind.reports.writing_analysis.total_posts"
                }}</div>
              <div class="writing-analysis__stats-value">{{dNumber
                  @report.data.total_posts
                }}</div>
            </div>

            <div class="writing-analysis__stats-col">
              <div class="writing-analysis__stats-label">{{i18n
                  "discourse_rewind.reports.writing_analysis.avg_post_length"
                }}</div>
              <div class="writing-analysis__stats-value">{{dNumber
                  @report.data.average_post_length
                }}</div>

              <div class="writing-analysis__stats-label">{{i18n
                  "discourse_rewind.reports.writing_analysis.readability_score_label"
                }}</div>
              <div class="writing-analysis__stats-value">{{dNumber
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
  </template>
}
