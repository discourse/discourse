import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { and, eq, not } from "discourse/truth-helpers";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class Revision extends Component {
  @service site;
  @service siteSettings;

  <template>
    <div id="revision">
      <div id="revision-details">
        {{dIcon "pencil"}}
        <LinkTo
          @route="user"
          @model={{@model.username}}
          class="revision-details__user"
        >
          {{dBoundAvatarTemplate @model.avatar_template "small"}}
          {{#if this.siteSettings.prioritize_full_name_in_ux}}
            {{@model.acting_user_name}}
          {{else}}
            {{@model.username}}
          {{/if}}
        </LinkTo>
        <PluginOutlet
          @name="revision-user-details-after"
          @outletArgs={{lazyHash model=@model}}
        />

        <span class="date">
          {{dAgeWithTooltip @model.created_at format="medium"}}
        </span>

        {{#if @model.edit_reason}}
          <span class="edit-reason">{{@model.edit_reason}}</span>
        {{/if}}

        {{#if this.site.desktopView}}
          <span>
            {{#if @model.user_changes}}
              {{dBoundAvatarTemplate
                @model.user_changes.previous.avatar_template
                "small"
              }}
              {{@model.user_changes.previous.username}}
              &rarr;
              {{dBoundAvatarTemplate
                @model.user_changes.current.avatar_template
                "small"
              }}
              {{@model.user_changes.current.username}}
            {{/if}}

            {{#if @model.wiki_changes}}
              {{dIcon
                "far-pen-to-square"
                class=(if @model.wiki_changes.current "diff-ins" "diff-del")
              }}
            {{/if}}

            {{#if @model.post_type_changes}}
              {{dIcon
                "shield-halved"
                class=(if
                  (eq
                    @model.post_type_changes.current
                    @site.post_types.moderator_action
                  )
                  "diff-del"
                  "diff-ins"
                )
              }}
            {{/if}}

            {{#if @model.archetype_changes}}
              {{dIcon
                (if
                  (eq @model.archetype_changes.current "private_message")
                  "envelope"
                  "comment"
                )
              }}
            {{/if}}

            {{#if
              (and @model.category_id_changes (not @model.archetype_changes))
            }}
              {{#if @previousCategory}}
                {{trustHTML @previousCategory}}
              {{else}}
                {{dIcon "far-eye-slash" class="diff-del"}}
              {{/if}}
              &rarr;
              {{#if @currentCategory}}
                {{trustHTML @currentCategory}}
              {{else}}
                {{dIcon "far-eye-slash" class="diff-ins"}}
              {{/if}}
            {{/if}}
          </span>
        {{/if}}
      </div>

      {{#if this.site.desktopView}}
        <div id="display-modes">
          <ul class="nav nav-pills">
            <li>
              <a
                href
                class={{dConcatClass
                  "inline-mode"
                  (if (eq @viewMode "inline") "active")
                }}
                {{on "click" @displayInline}}
                title={{i18n "post.revisions.displays.inline.title"}}
                aria-label={{i18n "post.revisions.displays.inline.title"}}
              >
                {{dIcon "far-square"}}
                {{i18n "post.revisions.displays.inline.button"}}
              </a>
            </li>
            <li>
              <a
                href
                class={{dConcatClass
                  "side-by-side-mode"
                  (if (eq @viewMode "side_by_side") "active")
                }}
                {{on "click" @displaySideBySide}}
                title={{i18n "post.revisions.displays.side_by_side.title"}}
                aria-label={{i18n "post.revisions.displays.side_by_side.title"}}
              >
                {{dIcon "table-columns"}}
                {{i18n "post.revisions.displays.side_by_side.button"}}
              </a>
            </li>
            <li>
              <a
                href
                class={{dConcatClass
                  "side-by-side-markdown-mode"
                  (if (eq @viewMode "side_by_side_markdown") "active")
                }}
                {{on "click" @displaySideBySideMarkdown}}
                title={{i18n
                  "post.revisions.displays.side_by_side_markdown.title"
                }}
                aria-label={{i18n
                  "post.revisions.displays.side_by_side_markdown.title"
                }}
              >
                {{dIcon "table-columns"}}
                {{i18n "post.revisions.displays.side_by_side_markdown.button"}}
              </a>
            </li>
          </ul>
        </div>
      {{/if}}
    </div>
  </template>
}
