import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import number from "discourse/helpers/number";
import { i18n } from "discourse-i18n";

export default class AiUsage extends Component {
  @service currentUser;

  matrixInterval = null;

  get totalRequests() {
    return this.args.report.data.total_requests ?? 0;
  }

  get totalTokens() {
    return this.args.report.data.total_tokens ?? 0;
  }

  get successRate() {
    return this.args.report.data.success_rate ?? 0;
  }

  get featureUsage() {
    return Object.entries(this.args.report.data.feature_usage ?? {})
      .filter(([name]) => name && name.trim().length > 0)
      .slice(0, 3);
  }

  get modelUsage() {
    return Object.entries(this.args.report.data.model_usage ?? {})
      .filter(([name]) => name && name.trim().length > 0)
      .slice(0, 3);
  }

  @action
  formatFeatureName(featureName) {
    return featureName.replace(/_/g, " ");
  }

  @action
  setupMatrix(element) {
    const canvas = element;
    const ctx = canvas.getContext("2d");

    canvas.width = element.offsetWidth;
    canvas.height = element.offsetHeight;

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

    this.matrixInterval = setInterval(draw, 33);
  }

  @action
  cleanupMatrix() {
    if (this.matrixInterval) {
      clearInterval(this.matrixInterval);
    }
  }

  <template>
    <div class="rewind-report-page --ai-usage">
      <div class="matrix-container">
        <canvas
          class="matrix-rain"
          {{didInsert this.setupMatrix}}
          {{willDestroy this.cleanupMatrix}}
        ></canvas>

        <div class="matrix-content">
          <h2 class="matrix-title">
            <div class="matrix-subhead">
              {{i18n
                "discourse_rewind.reports.ai_usage.wake_up"
                username=this.currentUser.username
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
                {{number this.totalRequests}}
              </div>
            </div>

            <div class="matrix-stat">
              <div class="matrix-stat__label">
                {{i18n "discourse_rewind.reports.ai_usage.total_tokens"}}
              </div>
              <div class="matrix-stat__value">{{number this.totalTokens}}</div>
            </div>

            <div class="matrix-stat">
              <div class="matrix-stat__label">
                {{i18n "discourse_rewind.reports.ai_usage.success_rate"}}
              </div>
              <div class="matrix-stat__value">
                <span class="number">
                  {{this.successRate}}%
                </span>
              </div>
            </div>
          </div>

          {{#if this.featureUsage.length}}
            <div class="matrix-section">
              <div class="matrix-section__title">&gt;
                {{i18n "discourse_rewind.reports.ai_usage.section_features"}}
              </div>
              <div class="matrix-list">
                {{#each this.featureUsage as |entry|}}
                  <div class="matrix-list__item">
                    <span class="matrix-list__name">
                      {{this.formatFeatureName (get entry "0")}}
                    </span>
                    <span class="matrix-list__count">{{get entry "1"}}</span>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}

          {{#if this.modelUsage.length}}
            <div class="matrix-section">
              <div class="matrix-section__title">&gt;
                {{i18n "discourse_rewind.reports.ai_usage.section_models"}}
              </div>
              <div class="matrix-list">
                {{#each this.modelUsage as |entry|}}
                  <div class="matrix-list__item">
                    <span class="matrix-list__name">{{get entry "0"}}</span>
                    <span class="matrix-list__count">{{get entry "1"}}</span>
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
