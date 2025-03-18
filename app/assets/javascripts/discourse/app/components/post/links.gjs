import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";

const MAX_COLLAPSED_LINKS = 5;

export default class PostLinks extends Component {
  @tracked collapsed;

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

  get shouldShowAllLinks() {
    return !this.collapsed || this.links?.length <= MAX_COLLAPSED_LINKS;
  }

  get displayedLinks() {
    if (this.shouldShowAllLinks) {
      return this.links;
    }
    return this.links.slice(0, MAX_COLLAPSED_LINKS);
  }

  get remainingCount() {
    return this.links.length - MAX_COLLAPSED_LINKS;
  }

  @action
  expandLinks() {
    this.collapsed = false;
  }

  <template>
    {{#if this.links}}
      <div class="post-links-container">
        <ul class="post-links">
          {{#each this.displayedLinks as |link|}}
            <li>
              <a
                class="track-link inbound"
                data-clicks={{link.clicks}}
                href={{link.url}}
              >
                {{icon "link"}}
                {{replaceEmoji link.title}}
              </a>
            </li>
          {{/each}}
          {{#unless this.shouldShowAllLinks}}
            <li>
              <DButton
                class="expand-links"
                @translatedLabel={{i18n
                  "post_links.title"
                  count=this.remainingCount
                }}
                @title="post_links.about"
                @action={{this.expandLinks}}
              />
            </li>
          {{/unless}}
        </ul>
      </div>
    {{/if}}
  </template>
}
