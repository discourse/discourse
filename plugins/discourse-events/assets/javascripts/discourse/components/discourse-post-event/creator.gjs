import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { groupPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

const INITIAL_HOSTS_COUNT = 2;

export default class DiscoursePostEventCreator extends Component {
  @service a11y;

  @tracked hostsExpanded = false;

  get creatorIsHost() {
    return this.args.hosts?.some(
      (host) => host.username === this.args.user?.username
    );
  }

  get hasHosts() {
    return this.hosts.length > 0;
  }

  get hasOrganizerGroup() {
    return !!this.args.organizerGroup;
  }

  get hosts() {
    return (this.args.hosts || []).filter(
      (host) => host.username !== this.args.user?.username
    );
  }

  get displayedHosts() {
    return this.hostsExpanded
      ? this.hosts
      : this.hosts.slice(0, INITIAL_HOSTS_COUNT);
  }

  get hasAdditionalHosts() {
    return this.hosts.length > INITIAL_HOSTS_COUNT;
  }

  get additionalHostsCount() {
    return this.hosts.length - INITIAL_HOSTS_COUNT;
  }

  get hostsToggleLabel() {
    if (this.hostsExpanded) {
      return i18n("discourse_post_event.show_fewer_hosts");
    }

    return i18n("discourse_post_event.other_hosts", {
      count: this.additionalHostsCount,
    });
  }

  get hostsLabel() {
    return this.creatorIsHost
      ? "discourse_post_event.co_hosted_by"
      : "discourse_post_event.hosted_by";
  }

  get organizerGroupName() {
    return this.args.organizerGroup?.displayName;
  }

  get organizerGroupPath() {
    return groupPath(this.args.organizerGroup?.name);
  }

  get username() {
    return this.args.user.name || formatUsername(this.args.user.username);
  }

  @action
  toggleHosts() {
    this.hostsExpanded = !this.hostsExpanded;
    this.a11y.announce(
      i18n(
        this.hostsExpanded
          ? "discourse_post_event.additional_hosts_shown"
          : "discourse_post_event.additional_hosts_hidden",
        { count: this.additionalHostsCount }
      ),
      "polite"
    );
  }

  usernameFor(user) {
    return user.name || formatUsername(user.username);
  }

  <template>
    <span class="creators">
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

          {{#if this.hasAdditionalHosts}}
            <DButton
              class="event-hosts__toggle"
              @action={{this.toggleHosts}}
              @ariaExpanded={{this.hostsExpanded}}
              @display="link"
              @translatedLabel={{this.hostsToggleLabel}}
            />
          {{/if}}
        </span>
      {{/if}}

      {{#if this.hasOrganizerGroup}}
        <span class="separator">·</span>
        <span class="event-organizer-group">
          <span class="organized-by">{{i18n
              "discourse_post_event.organized_by"
            }}</span>

          <a
            class="event-organizer-group__link"
            href={{this.organizerGroupPath}}
          >{{this.organizerGroupName}}</a>
        </span>
      {{/if}}
    </span>
  </template>
}
