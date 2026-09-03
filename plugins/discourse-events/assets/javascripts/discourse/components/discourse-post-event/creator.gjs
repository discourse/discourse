import Component from "@glimmer/component";
import { groupPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

export default class DiscoursePostEventCreator extends Component {
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

          {{#each this.hosts as |host|}}
            <span class="event-host">
              <a class="topic-invitee-avatar" data-user-card={{host.username}}>
                {{dAvatar host imageSize="tiny"}}
                <span class="username">{{this.usernameFor host}}</span>
              </a>
            </span>
          {{/each}}
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
