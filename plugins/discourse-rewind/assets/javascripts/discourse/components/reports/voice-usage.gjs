import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

function airtime(seconds) {
  const hours = Math.floor(seconds / 3600);
  if (hours > 0) {
    return i18n("discourse_rewind.reports.voice_usage.hours", { count: hours });
  }
  return i18n("discourse_rewind.reports.voice_usage.minutes", {
    count: Math.floor(seconds / 60),
  });
}

export default class VoiceUsage extends Component {
  get subtitleText() {
    return i18nForOwner(
      "discourse_rewind.reports.voice_usage.subtitle",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  get callCountText() {
    return i18n("discourse_rewind.reports.voice_usage.call_count", {
      count: this.args.report.data.call_count,
    });
  }

  <template>
    <div class="rewind-report-page --voice-usage">
      <div class="phone-bill">
        <div class="phone-bill__header">
          <div class="phone-bill__title">
            {{i18n "discourse_rewind.reports.voice_usage.title"}}
          </div>
          <div class="phone-bill__subtitle">{{this.subtitleText}}</div>
        </div>

        <div class="phone-bill__total">
          <div class="phone-bill__total-label">
            {{i18n "discourse_rewind.reports.voice_usage.total_airtime"}}
          </div>
          <div class="phone-bill__total-value">
            {{airtime @report.data.total_seconds}}
          </div>
          <div class="phone-bill__total-calls">{{this.callCountText}}</div>
        </div>

        {{#if @report.data.top_contacts.length}}
          <div class="phone-bill__section">
            <div class="phone-bill__section-title">
              {{i18n "discourse_rewind.reports.voice_usage.top_contacts"}}
            </div>
            <ol class="phone-bill__items">
              {{#each @report.data.top_contacts as |contact|}}
                <li class="phone-bill__item">
                  <a
                    class="phone-bill__item-name"
                    href={{userPath contact.user.username}}
                  >
                    {{dBoundAvatarTemplate
                      contact.user.avatar_template
                      "tiny"
                      (hash title=contact.user.username)
                    }}
                    @{{contact.user.username}}
                  </a>
                  <span class="phone-bill__item-leader"></span>
                  <span class="phone-bill__item-value">
                    {{airtime contact.seconds}}
                  </span>
                </li>
              {{/each}}
            </ol>
          </div>
        {{/if}}

        {{#if @report.data.top_rooms.length}}
          <div class="phone-bill__section">
            <div class="phone-bill__section-title">
              {{i18n "discourse_rewind.reports.voice_usage.top_rooms"}}
            </div>
            <ol class="phone-bill__items">
              {{#each @report.data.top_rooms as |room|}}
                <li class="phone-bill__item">
                  <a
                    class="phone-bill__item-name"
                    href={{getURL (concat "/voice/r/" room.slug)}}
                  >
                    {{room.name}}
                  </a>
                  <span class="phone-bill__item-leader"></span>
                  <span class="phone-bill__item-value">
                    {{airtime room.seconds}}
                  </span>
                </li>
              {{/each}}
            </ol>
          </div>
        {{/if}}

        <div class="phone-bill__footer">
          {{i18n "discourse_rewind.reports.voice_usage.amount_due"}}
        </div>
      </div>
    </div>
  </template>
}
