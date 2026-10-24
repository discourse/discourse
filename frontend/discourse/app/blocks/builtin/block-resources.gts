import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import BlockPanel from "discourse/blocks/block-panel";
import { ICON_NAME_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// A freshly added link starts with empty fields, so an empty value is valid
// while editing; incomplete links are left out when rendering.
const OPTIONAL_URL_PATTERN = new RegExp(
  `^$|${URL_PATTERN.source}`,
  URL_PATTERN.flags
);
const OPTIONAL_ICON_NAME_PATTERN = new RegExp(
  `^$|${ICON_NAME_PATTERN.source}`,
  ICON_NAME_PATTERN.flags
);

/** A resource link as authored; fields match the `link-list` block. */
interface ResourceItem {
  label?: string;
  url?: string;
  icon?: string;
  description?: string;
}

/** A resource link ready to render. */
interface ResourceLink {
  label: string;
  url: string;
  icon: string | null;
  description: string | null;
  external: boolean;
}

function isExternal(url: string): boolean {
  try {
    return (
      new URL(url, window.location.origin).origin !== window.location.origin
    );
  } catch {
    return false;
  }
}

// Drops incomplete items and resolves site paths against the base URL.
function normalizeLink(item: ResourceItem): ResourceLink | null {
  const label = item.label?.trim();
  const url = item.url?.trim();
  if (!label || !url) {
    return null;
  }
  const absolute = /^[a-z][a-z\d+.-]*:/i.test(url) || url.startsWith("//");
  return {
    label,
    url: absolute || url.startsWith("#") ? url : getURL(url),
    icon: item.icon?.trim() || null,
    description: item.description?.trim() || null,
    external: isExternal(url),
  };
}

interface BlockResourcesSignature {
  Args: {
    title?: string;
    icon?: string;
    links?: ResourceItem[];
  };
}

/**
 * A titled panel of links, each with an optional icon and description.
 * External links open in a new tab. Renders nothing without a complete link.
 */
@block("resources", {
  displayName: "Resources",
  icon: "book",
  category: "community",
  description: "A titled panel of links with icons and descriptions.",
  args: {
    title: {
      type: "string",
      default: "Resources",
      ui: { label: i18n("blocks.builtin.resources.title") },
    },
    icon: {
      type: "string",
      default: "book",
      ui: {
        control: "icon",
        label: i18n("blocks.builtin.resources.icon"),
      },
    },
    links: {
      type: "array",
      itemType: "object",
      default: [],
      itemSchema: {
        label: {
          type: "string",
          required: true,
          ui: { label: i18n("blocks.builtin.resources.link_label") },
        },
        url: {
          type: "string",
          required: true,
          pattern: OPTIONAL_URL_PATTERN,
          ui: {
            control: "url",
            label: i18n("blocks.builtin.resources.link_url"),
          },
        },
        icon: {
          type: "string",
          pattern: OPTIONAL_ICON_NAME_PATTERN,
          ui: {
            control: "icon",
            label: i18n("blocks.builtin.resources.link_icon"),
          },
        },
        description: {
          type: "string",
          ui: { label: i18n("blocks.builtin.resources.link_description") },
        },
      },
      ui: {
        control: "repeatable",
        label: i18n("blocks.builtin.resources.links"),
      },
    },
  },
})
export default class BlockResources extends Component<BlockResourcesSignature> {
  get links(): ResourceLink[] {
    return (this.args.links ?? [])
      .map(normalizeLink)
      .filter((link): link is ResourceLink => link !== null);
  }

  <template>
    {{#if this.links.length}}
      <BlockPanel class="d-block-resources" @icon={{@icon}} @title={{@title}}>
        <:content>
          <ul class="d-block-resources__list">
            {{#each this.links as |link|}}
              <li class="d-block-resources__item">
                <a
                  class="d-block-resources__link"
                  href={{link.url}}
                  rel={{if link.external "noopener noreferrer"}}
                  target={{if link.external "_blank"}}
                >
                  {{#if link.icon}}
                    <span class="d-block-resources__icon">{{dIcon
                        link.icon
                      }}</span>
                  {{/if}}
                  <span class="d-block-resources__details">
                    <span class="d-block-resources__label">{{link.label}}</span>
                    {{#if link.description}}
                      <span
                        class="d-block-resources__description"
                      >{{link.description}}</span>
                    {{/if}}
                  </span>
                </a>
              </li>
            {{/each}}
          </ul>
        </:content>
      </BlockPanel>
    {{/if}}
  </template>
}
