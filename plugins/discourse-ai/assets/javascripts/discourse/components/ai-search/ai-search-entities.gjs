import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { userPath } from "discourse/lib/url";
import { or } from "discourse/truth-helpers";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PER_KIND = 3;

/**
 * The users, groups, categories and tags the search found, kept to one line.
 * The menu shows only topics once a search runs, so these would otherwise be
 * lost to the reader who was typing a name.
 */
export default class AiSearchEntities extends Component {
  @service aiSearchSession;
  @service search;

  get results() {
    return this.search.results ?? {};
  }

  get categories() {
    return (this.results.categories ?? []).slice(0, PER_KIND);
  }

  get tags() {
    return (this.results.tags ?? []).slice(0, PER_KIND);
  }

  get users() {
    return (this.results.users ?? []).slice(0, PER_KIND).map((user) => ({
      user,
      url: userPath(user.username_lower ?? user.username),
    }));
  }

  get groups() {
    return (this.results.groups ?? []).slice(0, PER_KIND);
  }

  get dismissedScope() {
    return this.aiSearchSession.dismissedScope;
  }

  get hasEntities() {
    return (
      this.categories.length +
        this.tags.length +
        this.users.length +
        this.groups.length >
      0
    );
  }

  @action
  followLink(event) {
    if (event.target.closest("a")) {
      this.args.onNavigate?.();
    }
  }

  <template>
    {{#if (or this.hasEntities this.dismissedScope)}}
      {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
      <div
        aria-label={{i18n "discourse_ai.ai_search.entities_label"}}
        class="ai-search-entities"
        role="list"
        {{on "click" this.followLink}}
      >
        {{! a way back to the scope taken off, beside the other places to go }}
        {{#if this.dismissedScope}}
          <DButton
            class="btn-link ai-search-entities__restore"
            role="listitem"
            @action={{this.aiSearchSession.restoreScope}}
            @icon="filter"
            @translatedLabel={{i18n
              "discourse_ai.ai_search.scope.restore"
              name=this.dismissedScope.label
            }}
          />
        {{/if}}
        {{#each this.categories as |category|}}
          <span class="ai-search-entities__item" role="listitem">
            {{dCategoryLink category}}
          </span>
        {{/each}}
        {{#each this.tags as |tag|}}
          <a
            class="ai-search-entities__item --tag"
            href={{tag.url}}
            role="listitem"
          >
            {{dIcon "tag"}}
            {{dDiscourseTag tag.name tagName="span"}}
          </a>
        {{/each}}
        {{#each this.users as |entry|}}
          <a
            class="ai-search-entities__item --user"
            href={{entry.url}}
            role="listitem"
          >
            {{dAvatar entry.user imageSize="tiny"}}
            {{entry.user.username}}
          </a>
        {{/each}}
        {{#each this.groups as |group|}}
          <a
            class="ai-search-entities__item --group"
            href={{group.url}}
            role="listitem"
          >
            {{#if group.flairUrl}}
              <DAvatarFlair
                @flairBgColor={{group.flairBgColor}}
                @flairColor={{group.flairColor}}
                @flairName={{group.name}}
                @flairUrl={{group.flairUrl}}
              />
            {{else}}
              {{dIcon "users"}}
            {{/if}}
            {{or group.fullName group.name}}
          </a>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
