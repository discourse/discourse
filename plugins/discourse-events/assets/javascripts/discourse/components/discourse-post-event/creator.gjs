import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { formatUsername } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

const INITIAL_HOSTS_COUNT = 2;

export default class DiscoursePostEventCreator extends Component {
  @tracked hostsCollapsed = false;

  #collapsedAtWidth = null;

  get creatorIsHost() {
    return this.args.hosts?.some(
      (host) => host.username === this.args.user?.username
    );
  }

  get hasHosts() {
    return this.hosts.length > 0;
  }

  get hosts() {
    return (this.args.hosts || []).filter(
      (host) => host.username !== this.args.user?.username
    );
  }

  get displayedHosts() {
    return this.hostsCollapsed ? [] : this.hosts.slice(0, INITIAL_HOSTS_COUNT);
  }

  get hasHostsMenu() {
    return this.hostsCollapsed || this.hosts.length > INITIAL_HOSTS_COUNT;
  }

  get hostsMenuLabel() {
    if (this.hostsCollapsed) {
      return this.allHostsTitle;
    }

    return i18n("discourse_post_event.other_hosts", {
      count: this.hosts.length - INITIAL_HOSTS_COUNT,
    });
  }

  get allHostsTitle() {
    return i18n("discourse_post_event.all_hosts", {
      count: this.hosts.length,
    });
  }

  get hostsLabel() {
    return this.creatorIsHost
      ? "discourse_post_event.co_hosted_by"
      : "discourse_post_event.hosted_by";
  }

  get username() {
    return this.args.user.name || formatUsername(this.args.user.username);
  }

  // Collapses every host into the menu once the hosts line wraps below the
  // creator, and only tries the inline layout again once the row is wider than
  // it was when it wrapped, so resizing cannot flip-flop between the two.
  @action
  syncHostsLayout([entry]) {
    const row = entry.target;
    const width = row.clientWidth;

    if (this.hostsCollapsed) {
      if (width > this.#collapsedAtWidth) {
        this.#collapsedAtWidth = null;
        this.hostsCollapsed = false;
      }
      return;
    }

    const creator = row.querySelector(".event-creator");
    const hosts = row.querySelector(".event-hosts");
    if (creator && hosts && hosts.offsetTop > creator.offsetTop) {
      this.#collapsedAtWidth = width;
      this.hostsCollapsed = true;
    }
  }

  usernameFor(user) {
    return user.name || formatUsername(user.username);
  }

  <template>
    <span class="creators" {{dOnResize this.syncHostsLayout}}>
      <span class="created-by">{{i18n
          (if
            this.creatorIsHost
            "discourse_post_event.created_and_hosted_by"
            "discourse_post_event.created_by"
          )
        }}</span>

      <span class="event-creator">
        <a class="topic-invitee-avatar" data-user-card={{@user.username}}>
          {{dAvatar @user imageSize="tiny"}}
          <span class="username">{{this.username}}</span>
        </a>
      </span>

      {{#if this.hasHosts}}
        <span class="separator">·</span>
        <span class="event-hosts">
          <span class="hosted-by">{{i18n this.hostsLabel}}</span>

          {{#each this.displayedHosts as |host|}}
            <span class="event-host">
              <a class="topic-invitee-avatar" data-user-card={{host.username}}>
                {{dAvatar host imageSize="tiny"}}
                <span class="username">{{this.usernameFor host}}</span>
              </a>
            </span>
          {{/each}}

          {{#if this.hasHostsMenu}}
            <DMenu
              class="event-hosts__toggle"
              @identifier="discourse-post-event-hosts"
              @modalForMobile={{true}}
              @triggerComponent={{component
                DButton
                display="link"
                translatedLabel=this.hostsMenuLabel
              }}
            >
              <:content>
                <div class="event-hosts-menu">
                  <h3
                    class="event-hosts-menu__title"
                  >{{this.allHostsTitle}}</h3>
                  <ul class="event-hosts-menu__list">
                    {{#each this.hosts as |host|}}
                      <li class="event-hosts-menu__item">
                        <DUserLink
                          class="event-hosts-menu__host"
                          @user={{host}}
                        >
                          {{dAvatar host imageSize="small"}}
                          <span class="event-hosts-menu__name">
                            {{this.usernameFor host}}
                          </span>
                          {{#if host.name}}
                            <span class="event-hosts-menu__username">
                              {{formatUsername host.username}}
                            </span>
                          {{/if}}
                        </DUserLink>
                      </li>
                    {{/each}}
                  </ul>
                </div>
              </:content>
            </DMenu>
          {{/if}}
        </span>
      {{/if}}
    </span>
  </template>
}
