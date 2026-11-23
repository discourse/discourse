import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";

const PHOSPHOR_COLORS = ["#ffbf00", "#00ffff", "#ff00ff", "#0f0"];

export default class WritingAnalysis extends Component {
  @service rewind;

  keyListener = modifier(() => {
    const handleKeyDown = (event) => {
      if (event.key === "F1") {
        event.preventDefault();
        this.#phosphorIndex.value =
          (this.#phosphorIndex.value + 1) % PHOSPHOR_COLORS.length;
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  });

  #phosphorIndex = tracked(-1);

  get scoreLabel() {
    const score = this.args.report.data.readability_score;
    const bucket = [80, 60, 40, 20].find((min) => score >= min) ?? 0;
    const randomNum = Math.floor(Math.random() * 4) + 1;

    return i18n(
      `discourse_rewind.reports.writing_analysis.readability_score.over_${bucket}.${randomNum}`
    );
  }

  get meterStyle() {
    return trustHTML(`width: ${this.args.report.data.readability_score}%`);
  }

  get phosphorStyle() {
    const color = PHOSPHOR_COLORS[this.#phosphorIndex.value];
    return color
      ? trustHTML(`--rewind-ink: ${color}; --rewind-paper: #000`)
      : null;
  }

  <template>
    <div class="rewind-report-page --writing-analysis" {{this.keyListener}}>
      <h2 class="rewind-report-title">
        {{i18n "discourse_rewind.reports.writing_analysis.title"}}
      </h2>

      <div class="rewind-writing" style={{this.phosphorStyle}}>
        <RewindWindow
          class="rewind-writing__document"
          @title={{i18n "discourse_rewind.reports.writing_analysis.app_name"}}
        >
          <div class="rewind-writing__menu">
            <span>{{i18n
                "discourse_rewind.reports.writing_analysis.menu_file"
              }}</span>
            <span>{{i18n
                "discourse_rewind.reports.writing_analysis.menu_other"
              }}</span>
            <span>{{i18n
                "discourse_rewind.reports.writing_analysis.menu_additional"
              }}</span>
            <span>{{i18n
                "discourse_rewind.reports.writing_analysis.menu_opening"
              }}</span>
          </div>
          <div aria-hidden="true" class="rewind-writing__ruler"></div>
          <div class="rewind-leaders rewind-writing__page">
            <p>{{i18n
                "discourse_rewind.reports.writing_analysis.release_info"
                rewindYear=this.rewind.fetchRewindYear
              }}
              <span>&lt;3</span></p>
            <p>{{i18n
                "discourse_rewind.reports.writing_analysis.help_text"
              }}</p>
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.writing_analysis.total_words"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.total_words
                }}</span>
            </p>
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.writing_analysis.total_posts"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.total_posts
                }}</span>
            </p>
            <p class="rewind-leaders__row">
              {{i18n
                "discourse_rewind.reports.writing_analysis.avg_post_length"
              }}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.average_post_length
                }}</span>
            </p>
          </div>
        </RewindWindow>

        <RewindWindow
          class="rewind-writing__readability"
          @title={{i18n
            "discourse_rewind.reports.writing_analysis.readability_score_label"
          }}
        >
          <p class="rewind-writing__score">
            {{@report.data.readability_score}}<small>/100</small>
          </p>
          <div class="rewind-writing__meter">
            <span
              class="rewind-writing__meter-fill"
              style={{this.meterStyle}}
            ></span>
          </div>
          <p>{{i18n
              "discourse_rewind.reports.writing_analysis.readability_level"
            }}</p>
          <p class="rewind-writing__author">{{this.scoreLabel}}</p>
        </RewindWindow>
      </div>
    </div>
  </template>
}
