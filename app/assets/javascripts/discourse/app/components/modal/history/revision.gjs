import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, eq, not } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class Revision extends Component {
  @service site;
  @service siteSettings;

  <template>
    <div id="revision">
      <div id="revision-details">
        {{icon "pencil"}}
        <LinkTo
          @route="user"
          @model={{@model.username}}
          class="revision-details__user"
        >
          {{boundAvatarTemplate @model.avatar_template "small"}}
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
          {{ageWithTooltip @model.created_at format="medium"}}
        </span>

        {{#if @model.edit_reason}}
          <span class="edit-reason">{{@model.edit_reason}}</span>
        {{/if}}

        {{#if this.site.desktopView}}
          <span>
            {{#if @model.user_changes}}
              {{boundAvatarTemplate
                @model.user_changes.previous.avatar_template
                "small"
              }}
              {{@model.user_changes.previous.username}}
              &rarr;
              {{boundAvatarTemplate
                @model.user_changes.current.avatar_template
                "small"
              }}
              {{@model.user_changes.current.username}}
            {{/if}}

            {{#if @model.wiki_changes}}
              {{icon
                "far-pen-to-square"
                class=(if @model.wiki_changes.current "diff-ins" "diff-del")
              }}
            {{/if}}

            {{#if @model.post_type_changes}}
              {{icon
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
              {{icon
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
                {{htmlSafe @previousCategory}}
              {{else}}
                {{icon "far-eye-slash" class="diff-del"}}
              {{/if}}
              &rarr;
              {{#if @currentCategory}}
                {{htmlSafe @currentCategory}}
              {{else}}
                {{icon "far-eye-slash" class="diff-ins"}}
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
                class={{concatClass
                  "inline-mode"
                  (if (eq @viewMode "inline") "active")
                }}
                {{on "click" @displayInline}}
                title={{i18n "post.revisions.displays.inline.title"}}
                aria-label={{i18n "post.revisions.displays.inline.title"}}
              >
                {{icon "far-square"}}
                {{i18n "post.revisions.displays.inline.button"}}
              </a>
            </li>
            <li>
              <a
                href
                class={{concatClass
                  "side-by-side-mode"
                  (if (eq @viewMode "side_by_side") "active")
                }}
                {{on "click" @displaySideBySide}}
                title={{i18n "post.revisions.displays.side_by_side.title"}}
                aria-label={{i18n "post.revisions.displays.side_by_side.title"}}
              >
                {{icon "table-columns"}}
                {{i18n "post.revisions.displays.side_by_side.button"}}
              </a>
            </li>
            <li>
              <a
                href
                class={{concatClass
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
                {{icon "table-columns"}}
                {{i18n "post.revisions.displays.side_by_side_markdown.button"}}
              </a>
            </li>
          </ul>
        </div>
      {{/if}}
    </div>
  </template>
}
