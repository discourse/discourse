import Component from "@glimmer/component";
import UserProfileAvatar from "discourse/components/user-profile-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";

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
            <UserProfileAvatar @user={{@user}} @tagName="" />
          {{else}}
            {{this.avatarInitial}}
          {{/if}}
        </span>
      </div>

      <div class="horizon-site-skeleton__body">
        <aside class="horizon-site-skeleton__sidebar">
          <div class="horizon-site-skeleton__new-topic">New Topic</div>

          <div class="horizon-site-skeleton__nav-item --active">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "layer-group"}}
            </span>
            Topics
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "user"}}
            </span>
            My posts
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "inbox"}}
            </span>
            My messages
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "flag"}}
            </span>
            Review
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "wrench"}}
            </span>
            Admin
          </div>
          <div class="horizon-site-skeleton__nav-item">
            <span class="horizon-site-skeleton__nav-icon">
              {{dIcon "paper-plane"}}
            </span>
            Invite
          </div>

          <div class="horizon-site-skeleton__sidebar-section">
            <div class="horizon-site-skeleton__sidebar-title">
              Categories
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__category-dot --blue"></span>
              General
            </div>
            <div class="horizon-site-skeleton__category">
              <span
                class="horizon-site-skeleton__category-dot --light-blue"
              ></span>
              Site Feedback
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__category-dot --staff"></span>
              Staff
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__nav-icon">
                {{dIcon "list"}}
              </span>
              All categories
            </div>
          </div>

          <div class="horizon-site-skeleton__sidebar-section">
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__nav-icon">
                {{dIcon "magnifying-glass"}}
              </span>
              Search chat
            </div>
          </div>

          <div class="horizon-site-skeleton__sidebar-section">
            <div class="horizon-site-skeleton__sidebar-title">
              Channels
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__channel --blue"></span>
              General
            </div>
            <div class="horizon-site-skeleton__category">
              <span class="horizon-site-skeleton__channel --red"></span>
              Staff
            </div>
          </div>
        </aside>

        <main class="horizon-site-skeleton__content">
          <section class="horizon-site-skeleton__card">
            <div class="horizon-site-skeleton__setup-banner">
              <button type="button" tabindex="-1">x</button>
              <h3>Launch in 3 easy steps</h3>
              <div class="horizon-site-skeleton__setup-steps">
                <div>
                  <strong>Customize your site</strong>
                  <span>Choose a starting theme for your community</span>
                  <em>Select theme</em>
                </div>
                <div>
                  <strong>Invite Collaborators</strong>
                  <span>Early members help bring your community to life</span>
                  <em>Create invite</em>
                </div>
                <div>
                  <strong>Start Posting</strong>
                  <span>Give people something to talk about together</span>
                  <em>See ideas</em>
                </div>
              </div>
            </div>

            <div class="horizon-site-skeleton__welcome-row">
              <h3>Welcome back,<br />{{this.username}}!</h3>
              <div class="horizon-site-skeleton__search">
                <span class="horizon-site-skeleton__search-icon">
                  {{dIcon "magnifying-glass"}}
                </span>
                Search
                <span class="horizon-site-skeleton__search-icon --filters">
                  {{dIcon "sliders"}}
                </span>
              </div>
            </div>

            <div class="horizon-site-skeleton__tabs">
              <span class="--active">Latest</span>
              <span>Hot</span>
              <span>Categories</span>
              <button type="button" tabindex="-1">categories</button>
            </div>

            <div class="horizon-site-skeleton__topic-list">
              <div class="horizon-site-skeleton__topic">
                <span
                  class="horizon-site-skeleton__topic-avatar --system"
                ></span>
                <div class="horizon-site-skeleton__topic-main">
                  <span>posted Jun 1 by @system</span>
                  <strong>Welcome to {{this.siteName}}!</strong>
                  <p>
                    We are so glad you joined us. Here are some things you can
                    do to get started: Introduce yourself by adding your picture
                    and information about yourself...
                  </p>
                  <em>General</em>
                </div>
                <span class="horizon-site-skeleton__topic-pin">Pinned</span>
              </div>
              <div class="horizon-site-skeleton__topic">
                <span
                  class="horizon-site-skeleton__topic-avatar --system"
                ></span>
                <div class="horizon-site-skeleton__topic-main">
                  <span>posted Jun 1 by @system</span>
                  <strong>Admin Guide: Getting Started</strong>
                  <p>
                    Welcome to your new community, and thank you for choosing
                    Discourse! Invite your team. Start some conversations...
                  </p>
                  <em class="--staff">Staff</em>
                </div>
              </div>
              <div class="horizon-site-skeleton__topic">
                <span
                  class="horizon-site-skeleton__topic-avatar --system"
                ></span>
                <div class="horizon-site-skeleton__topic-main">
                  <span>posted Jun 1 by @system</span>
                  <strong>Guidelines</strong>
                  <p>
                    This is a civilized place for public discussion. Please
                    treat this discussion forum with the same respect...
                  </p>
                  <em class="--staff">Staff</em>
                </div>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
  </template>
}
