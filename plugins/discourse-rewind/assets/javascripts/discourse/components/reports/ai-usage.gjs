import Component from "@glimmer/component";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import { prefersReducedMotion } from "discourse/lib/utilities";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default class AiUsage extends Component {
  matrixRain = modifier((canvas) => {
    if (prefersReducedMotion()) {
      return;
    }

    const ctx = canvas.getContext("2d");

    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;

    const characters =
      "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン";
    const fontSize = 14;
    const columns = Math.floor(canvas.width / fontSize);
    const drops = Array(columns).fill(1);

    const draw = () => {
      ctx.fillStyle = "rgba(0, 0, 0, 0.05)";
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.fillStyle = "#0f0";
      ctx.font = `${fontSize}px monospace`;

      for (let i = 0; i < drops.length; i++) {
        const char = characters[Math.floor(Math.random() * characters.length)];
        const x = i * fontSize;
        const y = drops[i] * fontSize;

        ctx.fillText(char, x, y);

        if (y > canvas.height && Math.random() > 0.975) {
          drops[i] = 0;
        }

        drops[i]++;
      }
    };

    const interval = setInterval(draw, 33);
    return () => clearInterval(interval);
  });

  @action
  formatFeatureName(featureName) {
    return featureName.replace(/_/g, " ");
  }

  <template>
    <div class="rewind-report-page --ai-usage">
      <div class="matrix-container">
        <canvas class="matrix-rain" {{this.matrixRain}}></canvas>

        <div class="matrix-content">
          <h2 class="matrix-title">
            <div class="matrix-subhead">
              {{i18n
                "discourse_rewind.reports.ai_usage.wake_up"
                username=@user.username
              }}
            </div>
            {{i18n "discourse_rewind.reports.ai_usage.system_title"}}
          </h2>

          <div class="matrix-stats">
            <div class="matrix-stat">
              <div class="matrix-stat__label">
                {{i18n "discourse_rewind.reports.ai_usage.total_requests"}}
              </div>
              <div class="matrix-stat__value">
                {{dNumber @report.data.total_requests}}
              </div>
            </div>

            <div class="matrix-stat">
              <div class="matrix-stat__label">
                {{i18n "discourse_rewind.reports.ai_usage.total_tokens"}}
              </div>
              <div class="matrix-stat__value">{{dNumber
                  @report.data.total_tokens
                }}</div>
            </div>

            <div class="matrix-stat">
              <div class="matrix-stat__label">
                {{i18n "discourse_rewind.reports.ai_usage.success_rate"}}
              </div>
              <div class="matrix-stat__value">
                <span class="number">
                  {{@report.data.success_rate}}%
                </span>
              </div>
            </div>
          </div>

          {{#if @report.data.feature_usage.length}}
            <div class="matrix-section">
              <div class="matrix-section__title">&gt;
                {{i18n "discourse_rewind.reports.ai_usage.section_features"}}
              </div>
              <div class="matrix-list">
                {{#each @report.data.feature_usage as |entry|}}
                  <div class="matrix-list__item">
                    <span class="matrix-list__name">
                      {{this.formatFeatureName entry.name}}
                    </span>
                    <span class="matrix-list__count">{{entry.count}}</span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}

          {{#if @report.data.model_usage.length}}
            <div class="matrix-section">
              <div class="matrix-section__title">&gt;
                {{i18n "discourse_rewind.reports.ai_usage.section_models"}}
              </div>
              <div class="matrix-list">
                {{#each @report.data.model_usage as |entry|}}
                  <div class="matrix-list__item">
                    <span class="matrix-list__name">{{entry.name}}</span>
                    <span class="matrix-list__count">{{entry.count}}</span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
