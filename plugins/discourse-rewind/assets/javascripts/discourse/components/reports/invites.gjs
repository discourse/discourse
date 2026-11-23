import Component from "@glimmer/component";
import { userPath } from "discourse/lib/url";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const ENVELOPE_LIMIT = 36;

export default class Invites extends Component {
  get mostActiveInvitee() {
    return this.args.report.data.most_active_invitee;
  }

  get subtitleText() {
    return i18nForOwner(
      "discourse_rewind.reports.invites.guest_book_subtitle",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  /**
   * One envelope per invite, opened when the invite was accepted.
   */
  get envelopes() {
    const { total_invites: total, redeemed_count: redeemed } =
      this.args.report.data;
    const shown = Math.min(total, ENVELOPE_LIMIT);
    const opened = Math.round((redeemed / Math.max(total, 1)) * shown);
    return Array.from({ length: shown }, (_, index) => index < opened);
  }

  <template>
    <div class="rewind-report-page --invites">
      <h2 class="rewind-report-title">{{i18n
          "discourse_rewind.reports.invites.guest_book_title"
        }}</h2>
      <p class="rewind-report-page__lede">{{this.subtitleText}}</p>

      <div class="rewind-invites">
        <div class="rewind-invites__card">
          <ul aria-hidden="true" class="rewind-invites__envelopes">
            {{#each this.envelopes as |opened|}}
              <li class="rewind-invites__envelope {{if opened '--open'}}"></li>
            {{/each}}
          </ul>
          <div class="rewind-leaders">
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.invites.label_invitations_sent"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.total_invites
                }}</span>
            </p>
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.invites.label_guests_joined"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.redeemed_count
                }}</span>
            </p>
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.invites.label_acceptance_rate"}}
              <span
                class="rewind-leaders__value"
              >{{@report.data.redemption_rate}}%</span>
            </p>
          </div>
          <h3 class="rewind-invites__section">{{i18n
              "discourse_rewind.reports.invites.section_contributions"
            }}</h3>
          <div class="rewind-leaders">
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.invites.label_posts_written"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.invitee_post_count
                }}</span>
            </p>
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.invites.label_topics_started"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.invitee_topic_count
                }}</span>
            </p>
            <p class="rewind-leaders__row">
              {{i18n "discourse_rewind.reports.invites.label_likes_given"}}
              <span class="rewind-leaders__value">{{dNumber
                  @report.data.invitee_like_count
                }}</span>
            </p>
          </div>
        </div>

        {{#if this.mostActiveInvitee}}
          <figure class="rewind-invites__guest">
            <figcaption class="rewind-invites__section">{{i18n
                "discourse_rewind.reports.invites.section_most_active"
              }}</figcaption>
            <a
              aria-label={{this.mostActiveInvitee.username}}
              class="rewind-frame"
              href={{userPath this.mostActiveInvitee.username}}
            >
              {{dBoundAvatarTemplate
                this.mostActiveInvitee.avatar_template
                "huge"
                extraClasses="rewind-avatar"
                username=this.mostActiveInvitee.username
                name=this.mostActiveInvitee.name
              }}
            </a>
            <p class="rewind-invites__name">
              <b>{{this.mostActiveInvitee.username}}</b>
              {{#if this.mostActiveInvitee.name}}
                <span>{{this.mostActiveInvitee.name}}</span>
              {{/if}}
            </p>
          </figure>
        {{/if}}
      </div>
    </div>
  </template>
}
