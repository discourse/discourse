import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

function airtime(seconds) {
  const hours = Math.floor(seconds / 3600);

  if (hours > 0) {
    return i18n("discourse_rewind.reports.live_usage.hours", { count: hours });
  }

  return i18n("discourse_rewind.reports.live_usage.minutes", {
    count: Math.floor(seconds / 60),
  });
}

export default class LiveUsage extends Component {
  get subtitleText() {
    return i18nForOwner(
      "discourse_rewind.reports.live_usage.subtitle",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  get callCountText() {
    return i18n("discourse_rewind.reports.live_usage.call_count", {
      count: this.args.report.data.call_count,
    });
  }

  <template>
    <div class="rewind-report-page --live-usage">
      <h2 class="rewind-report-title">
        {{i18n "discourse_rewind.reports.live_usage.title"}}
      </h2>
      <p class="rewind-report-page__lede">{{this.subtitleText}}</p>

      <div class="rewind-calls">
        <RewindWindow class="rewind-calls__phone">
          <p class="rewind-calls__display">
            <span class="rewind-calls__label">{{i18n
                "discourse_rewind.reports.live_usage.total_airtime"
              }}</span>
            <span class="rewind-calls__total">{{airtime
                @report.data.total_seconds
              }}</span>
            <span>{{this.callCountText}}</span>
          </p>
        </RewindWindow>

        <div class="rewind-calls__logs">
          {{#if @report.data.top_contacts.length}}
            <RewindWindow
              @title={{i18n "discourse_rewind.reports.live_usage.top_contacts"}}
            >
              <ol class="rewind-calls__list">
                {{#each @report.data.top_contacts as |contact|}}
                  <li class="rewind-calls__entry">
                    <a
                      class="rewind-calls__name"
                      href={{userPath contact.user.username}}
                    >
                      {{dBoundAvatarTemplate
                        contact.user.avatar_template
                        "medium"
                        (hash
                          extraClasses="rewind-avatar"
                          title=contact.user.username
                        )
                      }}
                      @{{contact.user.username}}
                    </a>
                    <span>{{airtime contact.seconds}}</span>
                  </li>
                {{/each}}
              </ol>
            </RewindWindow>
          {{/if}}

          {{#if @report.data.top_rooms.length}}
            <RewindWindow
              @title={{i18n "discourse_rewind.reports.live_usage.top_rooms"}}
            >
              <ol class="rewind-calls__list">
                {{#each @report.data.top_rooms as |room|}}
                  <li class="rewind-calls__entry">
                    <a
                      class="rewind-calls__name --room"
                      href={{getURL (concat "/live/r/" room.slug)}}
                    >{{room.name}}</a>
                    <span>{{airtime room.seconds}}</span>
                  </li>
                {{/each}}
              </ol>
            </RewindWindow>
          {{/if}}

          <p class="rewind-calls__receipt">
            {{i18n "discourse_rewind.reports.live_usage.amount_due"}}
          </p>
        </div>
      </div>
    </div>
  </template>
}
