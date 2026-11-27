import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import { userPath } from "discourse/lib/url";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { CHANNELS_PANEL, DMS_PANEL } from "../lib/constants.js";

export default class MemberList extends Component {
  @service sidebarState;
  @service siteSettings;

  sectionTitle = (section) =>
    ["online", "offline"].includes(section.title)
      ? i18n(themePrefix(`member_list.${section.title}`))
      : section.title;

  displayName = (user) =>
    (this.siteSettings.prioritize_full_name_in_ux && user.name) ||
    user.username;

  isOnline = (user) => this.onlineIds.has(user.id);

  get show() {
    return (
      this.args.memberList.active &&
      [CHANNELS_PANEL, DMS_PANEL].includes(this.sidebarState.currentPanelKey)
    );
  }

  get onlineIds() {
    return new Set(this.args.memberList.onlineUsers.map((user) => user.id));
  }

  @action
  close() {
    this.args.memberList.slideOpen = false;
  }

  <template>
    {{! Always there, so core's user cards can listen for clicks on it. }}
    <div class="concord-member-list-host">
      {{#if this.show}}
        {{#if @memberList.compact}}
          {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
          <div
            class="concord-member-list__cloak"
            role="presentation"
            {{on "click" this.close}}
          ></div>
        {{else}}
          {{bodyClass "concord-member-list-open"}}
        {{/if}}
        <aside
          aria-label={{i18n (themePrefix "member_list.title")}}
          class={{dConcatClass
            "concord-member-list"
            (if @memberList.compact "--slide-in")
          }}
        >
          <DLoadMore
            @action={{@memberList.pager.loadMore}}
            @enabled={{not @memberList.pager.done}}
            @isLoading={{@memberList.pager.loading}}
          >
            {{#each @memberList.sections key="id" as |listSection|}}
              <section
                class="concord-member-list__section"
                data-section-id={{listSection.id}}
              >
                <h2 class="concord-member-list__heading">
                  {{#if listSection.icon}}{{dIcon listSection.icon}}{{/if}}
                  {{this.sectionTitle listSection}}
                  —
                  {{listSection.users.length}}
                </h2>

                {{#each listSection.users key="id" as |user|}}
                  <div
                    class={{dConcatClass
                      "concord-member-list__member"
                      (unless (this.isOnline user) "--offline")
                    }}
                    data-username={{user.username}}
                  >
                    <span class="concord-member-list__avatar">
                      <DUserAvatar @size="small" @user={{user}} />
                      {{#if (this.isOnline user)}}
                        <span class="concord-member-list__presence"></span>
                      {{/if}}
                    </span>
                    <a
                      class="concord-member-list__name"
                      data-user-card={{user.username}}
                      href={{userPath user.username}}
                    >{{this.displayName user}}</a>
                  </div>
                {{/each}}
              </section>
            {{/each}}
          </DLoadMore>
        </aside>
      {{/if}}
    </div>
  </template>
}
