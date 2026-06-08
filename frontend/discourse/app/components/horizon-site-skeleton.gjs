import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import UserProfileAvatar from "discourse/components/user-profile-avatar";
import { escapeExpression } from "discourse/lib/utilities";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class HorizonSiteSkeleton extends Component {
  get siteName() {
    return this.args.siteName || "your-community";
  }

  get username() {
    return this.args.user?.username || "member";
  }

  get avatarInitial() {
    return this.username[0];
  }

  get welcomeBack() {
    return i18n("horizon_site_skeleton.welcome_back", {
      username: escapeExpression(this.username),
    });
  }

  <template>
    <div class="horizon-site-skeleton" aria-hidden="true">
      <div class="horizon-site-skeleton__header">
        <div class="horizon-site-skeleton__brand">
          <span class="horizon-site-skeleton__menu">
            {{dIcon "bars"}}
          </span>
          <span class="horizon-site-skeleton__name">{{this.siteName}}</span>
        </div>
        <span class="horizon-site-skeleton__chat">
          {{dIcon "comment"}}
        </span>
        <span class="horizon-site-skeleton__avatar">
          {{#if @user}}
            <UserProfileAvatar @user={{@user}} />
          {{else}}
            {{this.avatarInitial}}
          {{/if}}
        </span>
      </div>

      <div class="horizon-site-skeleton__body">
        <aside class="horizon-site-skeleton__sidebar">
          <div class="horizon-site-skeleton__new-topic">
            {{i18n "horizon_site_skeleton.new_topic"}}
          </div>

          <div class="horizon-site-skeleton__nav-item --active">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "layer-group"}}
            </span>
            {{i18n "horizon_site_skeleton.nav.topics"}}
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "user"}}
            </span>
            {{i18n "horizon_site_skeleton.nav.my_posts"}}
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "inbox"}}
            </span>
            {{i18n "horizon_site_skeleton.nav.my_messages"}}
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "flag"}}
            </span>
            {{i18n "horizon_site_skeleton.nav.review"}}
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "wrench"}}
            </span>
            {{i18n "horizon_site_skeleton.nav.admin"}}
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "paper-plane"}}
            </span>
            {{i18n "horizon_site_skeleton.nav.invite"}}
          </div>

          <div class="horizon-site-skeleton__sidebar-section">
            <div class="horizon-site-skeleton__sidebar-title">
              {{i18n "horizon_site_skeleton.categories_title"}}
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__category-dot --blue"></span>
              {{i18n "horizon_site_skeleton.categories.general"}}
            </div>
            <div class="horizon-site-skeleton__category">
              <span
                class="horizon-site-skeleton__category-dot --light-blue"
              ></span>
              {{i18n "horizon_site_skeleton.categories.site_feedback"}}
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__category-dot --staff"></span>
              {{i18n "horizon_site_skeleton.categories.staff"}}
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__nav-icon">
                {{dIcon "list"}}
              </span>
              {{i18n "horizon_site_skeleton.categories.all"}}
            </div>
          </div>

          <div class="horizon-site-skeleton__sidebar-section">
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__nav-icon">
                {{dIcon "magnifying-glass"}}
              </span>
              {{i18n "horizon_site_skeleton.search_chat"}}
            </div>
          </div>

          <div class="horizon-site-skeleton__sidebar-section">
            <div class="horizon-site-skeleton__sidebar-title">
              {{i18n "horizon_site_skeleton.channels_title"}}
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__channel --blue"></span>
              {{i18n "horizon_site_skeleton.channels.general"}}
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__channel --red"></span>
              {{i18n "horizon_site_skeleton.channels.staff"}}
            </div>
          </div>
        </aside>

        <main class="horizon-site-skeleton__content">
          <section class="horizon-site-skeleton__card">
            <div class="horizon-site-skeleton__setup-banner">
              <button type="button" tabindex="-1">{{dIcon "xmark"}}</button>
              <h3>{{i18n "horizon_site_skeleton.setup.title"}}</h3>
              <div class="horizon-site-skeleton__setup-steps">
                <div>
                  <strong>{{i18n
                      "horizon_site_skeleton.setup.customize.title"
                    }}</strong>
                  <span>{{i18n
                      "horizon_site_skeleton.setup.customize.description"
                    }}</span>
                  <em>{{i18n
                      "horizon_site_skeleton.setup.customize.action"
                    }}</em>
                </div>
                <div>
                  <strong>{{i18n
                      "horizon_site_skeleton.setup.invite.title"
                    }}</strong>
                  <span>{{i18n
                      "horizon_site_skeleton.setup.invite.description"
                    }}</span>
                  <em>{{i18n "horizon_site_skeleton.setup.invite.action"}}</em>
                </div>
                <div>
                  <strong>{{i18n
                      "horizon_site_skeleton.setup.post.title"
                    }}</strong>
                  <span>{{i18n
                      "horizon_site_skeleton.setup.post.description"
                    }}</span>
                  <em>{{i18n "horizon_site_skeleton.setup.post.action"}}</em>
                </div>
              </div>
            </div>

            <div class="horizon-site-skeleton__welcome-row">
              <h3>{{trustHTML this.welcomeBack}}</h3>
              <div class="horizon-site-skeleton__search">
                <span class="horizon-site-skeleton__search-icon">
                  {{dIcon "magnifying-glass"}}
                </span>
                {{i18n "horizon_site_skeleton.search_placeholder"}}
                <span class="horizon-site-skeleton__search-icon --filters">
                  {{dIcon "sliders"}}
                </span>
              </div>
            </div>

            <div class="horizon-site-skeleton__tabs">
              <span class="--active">{{i18n
                  "horizon_site_skeleton.tabs.latest"
                }}</span>
              <span>{{i18n "horizon_site_skeleton.tabs.hot"}}</span>
              <span>{{i18n "horizon_site_skeleton.tabs.categories"}}</span>
              <button type="button" tabindex="-1">{{i18n
                  "horizon_site_skeleton.tabs.categories"
                }}</button>
            </div>

            <div class="horizon-site-skeleton__topic-list">
              <div class="horizon-site-skeleton__topic">
                <span
                  class="horizon-site-skeleton__topic-avatar --system"
                ></span>
                <div class="horizon-site-skeleton__topic-main">
                  <span>{{i18n "horizon_site_skeleton.topic.meta"}}</span>
                  <strong>{{i18n
                      "horizon_site_skeleton.topic.welcome.title"
                      site_name=this.siteName
                    }}</strong>
                  <p>
                    {{i18n "horizon_site_skeleton.topic.welcome.excerpt"}}
                  </p>
                  <em>{{i18n
                      "horizon_site_skeleton.topic.welcome.category"
                    }}</em>
                </div>
                <span class="horizon-site-skeleton__topic-pin">{{i18n
                    "horizon_site_skeleton.topic.pinned"
                  }}</span>
              </div>
              <div class="horizon-site-skeleton__topic">
                <span
                  class="horizon-site-skeleton__topic-avatar --system"
                ></span>
                <div class="horizon-site-skeleton__topic-main">
                  <span>{{i18n "horizon_site_skeleton.topic.meta"}}</span>
                  <strong>{{i18n
                      "horizon_site_skeleton.topic.admin_guide.title"
                    }}</strong>
                  <p>
                    {{i18n "horizon_site_skeleton.topic.admin_guide.excerpt"}}
                  </p>
                  <em class="--staff">{{i18n
                      "horizon_site_skeleton.topic.admin_guide.category"
                    }}</em>
                </div>
              </div>
              <div class="horizon-site-skeleton__topic">
                <span
                  class="horizon-site-skeleton__topic-avatar --system"
                ></span>
                <div class="horizon-site-skeleton__topic-main">
                  <span>{{i18n "horizon_site_skeleton.topic.meta"}}</span>
                  <strong>{{i18n
                      "horizon_site_skeleton.topic.guidelines.title"
                    }}</strong>
                  <p>
                    {{i18n "horizon_site_skeleton.topic.guidelines.excerpt"}}
                  </p>
                  <em class="--staff">{{i18n
                      "horizon_site_skeleton.topic.guidelines.category"
                    }}</em>
                </div>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
  </template>
}
