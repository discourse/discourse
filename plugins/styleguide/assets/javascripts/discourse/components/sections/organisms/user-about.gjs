import DButton from "discourse/components/d-button";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import boundAvatar from "discourse/helpers/bound-avatar";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const UserAbout = <template>
  <StyleguideExample @title=".user-main .about.collapsed-info.no-background">
    <section class="user-main">
      <section class="collapsed-info about no-background">
        <div class="profile-image"></div>

        <div class="details">
          <div class="primary">
            {{boundAvatar @dummy.user "huge"}}
            <section class="controls">
              <ul>
                <li>
                  <a class="btn btn-primary">
                    {{icon "envelope"}}
                    {{i18n "user.private_message"}}
                  </a>
                </li>
                <li>
                  <a href={{@dummy.user.adminPath}} class="btn">
                    {{icon "wrench"}}
                    {{i18n "admin.user.show_admin_profile"}}
                  </a>
                </li>
                <li>
                  <a href="#" class="btn">
                    {{icon "angles-down"}}
                    {{i18n "user.expand_profile"}}
                  </a>
                </li>
              </ul>
            </section>

            <div class="primary-textual">
              <h1 class="username">
                {{@dummy.user.username}}
                {{icon "shield-halved"}}
              </h1>
              <h2 class="full-name">{{@dummy.user.name}}</h2>
              <h3>{{@dummy.user.title}}</h3>
            </div>
          </div>
          <div style="clear: both"></div>
        </div>
      </section>
    </section>
  </StyleguideExample>

  <StyleguideExample @title=".user-main .about.collapsed-info.has-background">
    <section class="user-main">
      <section
        class="collapsed-info about has-background"
        style={{@dummy.user.profileBackground}}
      >
        <div class="profile-image"></div>
        <div class="details">
          <div class="primary">
            {{boundAvatar @dummy.user "huge"}}
            <section class="controls">
              <ul>
                <li>
                  <a class="btn btn-primary">
                    {{icon "envelope"}}
                    {{i18n "user.private_message"}}
                  </a>
                </li>
                <li>
                  <a href={{@dummy.user.adminPath}} class="btn">
                    {{icon "wrench"}}
                    {{i18n "admin.user.show_admin_profile"}}
                  </a>
                </li>
                <li>
                  <a href="#" class="btn">
                    {{icon "angles-down"}}
                    {{i18n "user.expand_profile"}}
                  </a>
                </li>
              </ul>
            </section>

            <div class="primary-textual">
              <h1 class="username">
                {{@dummy.user.username}}
                {{icon "shield-halved"}}
              </h1>
              <h2 class="full-name">{{@dummy.user.name}}</h2>
              <h3>{{@dummy.user.title}}</h3>
            </div>
          </div>
          <div style="clear: both"></div>
        </div>
      </section>
    </section>
  </StyleguideExample>

  <StyleguideExample @title=".user-main .about.no-background">
    <section class="user-main">
      <section class="about no-background">

        <div class="staff-counters">
          <div>
            <span class="helpful-flags">
              {{@dummy.user.number_of_flags_given}}
            </span>&nbsp;{{i18n "user.staff_counters.flags_given"}}
          </div>
          <div>
            <a href="#">
              <span class="flagged-posts">
                {{@dummy.user.number_of_flagged_posts}}
              </span>&nbsp;{{i18n "user.staff_counters.flagged_posts"}}
            </a>
          </div>
          <div>
            <a href="#">
              <span class="deleted-posts">
                {{@dummy.user.number_of_deleted_posts}}
              </span>&nbsp;{{i18n "user.staff_counters.deleted_posts"}}
            </a>
          </div>
          <div>
            <span class="suspensions">
              {{@dummy.user.number_of_suspensions}}
            </span>&nbsp;{{i18n "user.staff_counters.suspensions"}}
          </div>
          <div>
            <span class="warnings-received">
              {{@dummy.user.warnings_received_count}}
            </span>&nbsp;{{i18n "user.staff_counters.warnings_received"}}
          </div>
        </div>

        <div class="profile-image"></div>
        <div class="details">
          <div class="primary">
            {{boundAvatar @dummy.user "huge"}}
            <section class="controls">
              <ul>
                <li>
                  <a class="btn btn-primary">
                    {{icon "envelope"}}
                    {{i18n "user.private_message"}}
                  </a>
                </li>
                <li>
                  <a href={{@dummy.user.adminPath}} class="btn">
                    {{icon "wrench"}}
                    {{i18n "admin.user.show_admin_profile"}}
                  </a>
                </li>
              </ul>
            </section>

            <div class="primary-textual">
              <h1 class="username">
                {{@dummy.user.username}}
                {{icon "shield-halved"}}
              </h1>
              <h2 class="full-name">{{@dummy.user.name}}</h2>
              <h3>{{@dummy.user.title}}</h3>
              <h3>
                {{icon "location-dot"}}
                {{@dummy.user.location}}
                {{icon "globe"}}
                <a
                  href={{@dummy.user.website}}
                  rel="nofollow noopener noreferrer"
                  target="_blank"
                >
                  {{@dummy.user.website_name}}
                </a>
              </h3>

              <div class="bio">
                <div class="suspended">
                  {{icon "ban"}}
                  <b>
                    {{i18n
                      "user.suspended_notice"
                      date=@dummy.user.suspendedTillDate
                    }}
                  </b>
                  <br />
                  <b>{{i18n "user.suspended_reason"}}</b>
                  {{@dummy.user.suspend_reason}}
                </div>
                {{htmlSafe @dummy.user.bio_cooked}}
              </div>

              <div class="public-user-fields">
                {{#each @dummy.user.publicUserFields as |uf|}}
                  {{#if uf.value}}
                    <div class="public-user-field {{uf.field.dasherized_name}}">
                      <span class="user-field-name">{{uf.field.name}}
                      </span>:
                      <span class="user-field-value">{{uf.value}}
                      </span>
                    </div>
                  {{/if}}
                {{/each}}
              </div>
            </div>
          </div>
          <div style="clear: both"></div>
        </div>

        <div class="secondary">
          <dl>
            <dt>{{i18n "user.created"}}</dt>
            <dd>
              {{ageWithTooltip @dummy.user.created_at format="medium"}}
            </dd>
            <dt>{{i18n "user.last_posted"}}</dt>
            <dd>
              {{ageWithTooltip @dummy.user.last_posted_at format="medium"}}
            </dd>
            <dt>{{i18n "user.last_seen"}}</dt>
            <dd>
              {{ageWithTooltip @dummy.user.last_seen_at format="medium"}}
            </dd>
            <dt>{{i18n "views"}}</dt>
            <dd>{{@dummy.user.profile_view_count}}</dd>
            <dt class="invited-by">{{i18n "user.invited_by"}}</dt>
            <dd class="invited-by">
              <a href="#">{{@dummy.user.invited_by.username}}</a>
            </dd>
            <dt class="trust-level">{{i18n "user.trust_level"}}</dt>
            <dd class="trust-level">{{@dummy.user.trustLevel.name}}</dd>
            <dt>{{i18n "user.email.title"}}</dt>
            <dd title={{@dummy.user.email}}>
              <DButton
                @icon="envelope"
                @label="admin.users.check_email.text"
                class="btn-primary"
              />
            </dd>
            <dt class="groups">
              {{i18n "groups.title" count=@dummy.user.displayGroups.length}}
            </dt>
            <dd class="groups">
              {{#each @dummy.user.displayGroups as |group|}}
                <span>
                  <a href="#" class="group-link">{{group.name}}</a>
                </span>
              {{/each}}
            </dd>
            <DButton
              @icon="triangle-exclamation"
              @label="user.admin_delete"
              class="btn-danger"
            />
          </dl>
        </div>
      </section>
    </section>
  </StyleguideExample>

  <StyleguideExample @title=".user-main .about.has-background">
    <section class="user-main">
      <section
        class="about has-background"
        style={{@dummy.user.profileBackground}}
      >
        <div class="staff-counters">
          <div>
            <span class="helpful-flags">
              {{@dummy.user.number_of_flags_given}}
            </span>&nbsp;{{i18n "user.staff_counters.flags_given"}}
          </div>
          <div>
            <a href="#">
              <span class="flagged-posts">
                {{@dummy.user.number_of_flagged_posts}}
              </span>&nbsp;{{i18n "user.staff_counters.flagged_posts"}}
            </a>
          </div>
          <div>
            <a href="#">
              <span class="deleted-posts">
                {{@dummy.user.number_of_deleted_posts}}
              </span>&nbsp;{{i18n "user.staff_counters.deleted_posts"}}
            </a>
          </div>
          <div>
            <span class="suspensions">
              {{@dummy.user.number_of_suspensions}}
            </span>&nbsp;{{i18n "user.staff_counters.suspensions"}}
          </div>
          <div>
            <span class="warnings-received">
              {{@dummy.user.warnings_received_count}}
            </span>&nbsp;{{i18n "user.staff_counters.warnings_received"}}
          </div>
        </div>

        <div class="profile-image"></div>
        <div class="details">
          <div class="primary">
            {{boundAvatar @dummy.user "huge"}}
            <section class="controls">
              <ul>
                <li>
                  <a class="btn btn-primary">
                    {{icon "envelope"}}
                    {{i18n "user.private_message"}}
                  </a>
                </li>
                <li>
                  <a href={{@dummy.user.adminPath}} class="btn">
                    {{icon "wrench"}}
                    {{i18n "admin.user.show_admin_profile"}}
                  </a>
                </li>
              </ul>
            </section>

            <div class="primary-textual">
              <h1 class="username">
                {{@dummy.user.username}}
                {{icon "shield-halved"}}
              </h1>
              <h2 class="full-name">{{@dummy.user.name}}</h2>
              <h3>{{@dummy.user.title}}</h3>
              <h3>
                {{icon "location-dot"}}
                {{@dummy.user.location}}
                {{icon "globe"}}
                <a
                  href={{@dummy.user.website}}
                  rel="nofollow noopener noreferrer"
                  target="_blank"
                >
                  {{@dummy.user.website_name}}
                </a>
              </h3>

              <div class="bio">
                <div class="suspended">
                  {{icon "ban"}}
                  <b>
                    {{i18n
                      "user.suspended_notice"
                      date=@dummy.user.suspendedTillDate
                    }}
                  </b>
                  <br />
                  <b>{{i18n "user.suspended_reason"}}</b>
                  {{@dummy.user.suspend_reason}}
                </div>
                {{htmlSafe @dummy.user.bio_cooked}}
              </div>

              <div class="public-user-fields">
                {{#each @dummy.user.publicUserFields as |uf|}}
                  {{#if uf.value}}
                    <div class="public-user-field {{uf.field.dasherized_name}}">
                      <span class="user-field-name">{{uf.field.name}}</span>:
                      <span class="user-field-value">{{uf.value}}</span>
                    </div>
                  {{/if}}
                {{/each}}
              </div>
            </div>
          </div>
          <div style="clear: both"></div>
        </div>

        <div class="secondary">
          <dl>
            <dt>{{i18n "user.created"}}</dt>
            <dd>
              {{ageWithTooltip @dummy.user.created_at format="medium"}}
            </dd>
            <dt>{{i18n "user.last_posted"}}</dt>
            <dd>
              {{ageWithTooltip @dummy.user.last_posted_at format="medium"}}
            </dd>
            <dt>{{i18n "user.last_seen"}}</dt>
            <dd>
              {{ageWithTooltip @dummy.user.last_seen_at format="medium"}}
            </dd>
            <dt>{{i18n "views"}}</dt>
            <dd>{{@dummy.user.profile_view_count}}</dd>
            <dt class="invited-by">{{i18n "user.invited_by"}}</dt>
            <dd class="invited-by">
              <a href="#">{{@dummy.user.invited_by.username}}</a>
            </dd>
            <dt class="trust-level">{{i18n "user.trust_level"}}</dt>
            <dd class="trust-level">{{@dummy.user.trustLevel.name}}</dd>
            <dt>{{i18n "user.email.title"}}</dt>
            <dd title={{@dummy.user.email}}>
              <DButton
                @icon="envelope"
                @label="admin.users.check_email.text"
                class="btn-primary"
              />
            </dd>
            <dt class="groups">
              {{i18n "groups.title" count=@dummy.user.displayGroups.length}}
            </dt>
            <dd class="groups">
              {{#each @dummy.user.displayGroups as |group|}}
                <span>
                  <a href="#" class="group-link">{{group.name}}</a>
                </span>
              {{/each}}
            </dd>
            <DButton
              @icon="triangle-exclamation"
              @label="user.admin_delete"
              class="btn-danger"
            />
          </dl>
        </div>
      </section>
    </section>
  </StyleguideExample>
</template>;

export default UserAbout;
