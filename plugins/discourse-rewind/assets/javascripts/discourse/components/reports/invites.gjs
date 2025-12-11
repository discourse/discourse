import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import avatar from "discourse/helpers/bound-avatar-template";
import number from "discourse/helpers/number";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class Invites extends Component {
  get mostActiveInvitee() {
    return this.args.report.data.most_active_invitee;
  }

  get minimumDataThresholdMet() {
    return (
      this.args.report.data.total_invites >= 2 &&
      this.args.report.data.redeemed_count >= 1 &&
      this.args.report.data.invitee_post_count >= 5
    );
  }

  <template>
    {{#if this.minimumDataThresholdMet}}
      <div class="rewind-report-page --invites">
        <div class="guest-book">
          <div class="guest-book__cover">
            <div class="guest-book__title">
              {{i18n "discourse_rewind.reports.invites.guest_book_title"}}
            </div>
            <div class="guest-book__subtitle">
              {{i18n "discourse_rewind.reports.invites.guest_book_subtitle"}}
            </div>
          </div>

          <div class="guest-book__page">
            <div class="guest-book__entry">
              <div class="guest-book__entry-label">
                {{i18n
                  "discourse_rewind.reports.invites.label_invitations_sent"
                }}
              </div>
              <div class="guest-book__entry-value">
                {{number @report.data.total_invites}}
              </div>
            </div>

            <div class="guest-book__entry">
              <div class="guest-book__entry-label">
                {{i18n "discourse_rewind.reports.invites.label_guests_joined"}}
              </div>
              <div class="guest-book__entry-value">
                {{number @report.data.redeemed_count}}
              </div>
            </div>

            <div class="guest-book__entry">
              <div class="guest-book__entry-label">
                {{i18n
                  "discourse_rewind.reports.invites.label_acceptance_rate"
                }}
              </div>
              <div class="guest-book__entry-value">
                {{@report.data.redemption_rate}}%
              </div>
            </div>

            <div class="guest-book__divider"></div>

            <div class="guest-book__section-title">
              {{i18n "discourse_rewind.reports.invites.section_contributions"}}
            </div>

            <div class="guest-book__entry --small">
              <div class="guest-book__entry-label">
                {{i18n "discourse_rewind.reports.invites.label_posts_written"}}
              </div>
              <div class="guest-book__entry-value">
                {{number @report.data.invitee_post_count}}
              </div>
            </div>

            <div class="guest-book__entry --small">
              <div class="guest-book__entry-label">
                {{i18n "discourse_rewind.reports.invites.label_topics_started"}}
              </div>
              <div class="guest-book__entry-value">
                {{number @report.data.invitee_topic_count}}
              </div>
            </div>

            <div class="guest-book__entry --small">
              <div class="guest-book__entry-label">
                {{i18n "discourse_rewind.reports.invites.label_likes_given"}}
              </div>
              <div class="guest-book__entry-value">
                {{number @report.data.invitee_like_count}}
              </div>
            </div>

            {{#if this.mostActiveInvitee}}
              <div class="guest-book__divider"></div>

              <div class="guest-book__section-title">
                {{i18n "discourse_rewind.reports.invites.section_most_active"}}
              </div>

              <a
                href={{getURL (concat "/u/" this.mostActiveInvitee.username)}}
                class="guest-book__signature"
              >
                {{avatar
                  this.mostActiveInvitee.avatar_template
                  "large"
                  username=this.mostActiveInvitee.username
                  name=this.mostActiveInvitee.name
                }}
                <div class="guest-book__signature-info">
                  <span class="guest-book__signature-name">
                    {{this.mostActiveInvitee.username}}
                  </span>
                  {{#if this.mostActiveInvitee.name}}
                    <span class="guest-book__signature-realname">
                      {{this.mostActiveInvitee.name}}
                    </span>
                  {{/if}}
                </div>
              </a>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
