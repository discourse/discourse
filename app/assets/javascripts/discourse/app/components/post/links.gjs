import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";

const MAX_COLLAPSED_LINKS = 5;

export default class PostLinks extends Component {
  @tracked collapsed = true;

  @cached
  get links() {
    return this.args.post.internalLinks
      ?.filter((l) => l.reflection)
      ?.reduce((unique, item) => {
        if (!unique.find((i) => item.title === i.title)) {
          unique.push(item);
        }
        return unique;
      }, []);
  }

  get canExpandList() {
    return this.links?.length > MAX_COLLAPSED_LINKS && this.collapsed;
  }

  get displayedLinks() {
    if (!this.canExpandList) {
      return this.links;
    }
    return this.links.slice(0, MAX_COLLAPSED_LINKS);
  }

  get remainingCount() {
    return this.links.length - MAX_COLLAPSED_LINKS;
  }

  @action
  expandList() {
    this.collapsed = false;
  }

  <template>
    {{#if this.links}}
      <div class="post-links-container">
        <ul class="post-links">
          {{#each this.displayedLinks key="title" as |link|}}
            <li>
              <a
                class="track-link inbound"
                data-clicks={{if (gt link.clicks 0) link.clicks}}
                href={{link.url}}
              >
                {{icon "link"}}
                {{replaceEmoji link.title}}
              </a>
            </li>
          {{/each}}
          {{#if this.canExpandList}}
            <li>
              <DButton
                class="btn-transparent expand-links"
                @translatedLabel={{i18n
                  "post_links.title"
                  count=this.remainingCount
                }}
                @title="post_links.about"
                @action={{this.expandList}}
              />
            </li>
          {{/if}}
        </ul>
      </div>
    {{/if}}
  </template>
}
