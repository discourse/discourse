import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { type ComponentLike } from "@glint/template";
import { block } from "discourse/blocks";
import BlockImage from "discourse/blocks/block-image";
import type { BlockImageValue } from "discourse/blocks/image-value";
import { WELCOME_BANNER_BLOCK } from "discourse/components/welcome-banner";
import WelcomeBannerSearchUntyped from "discourse/components/welcome-banner-search";
import {
  welcomeBannerAudience,
  welcomeBannerHeader,
  welcomeBannerSubheader,
} from "discourse/lib/welcome-banner-text";
import type Site from "discourse/models/site";
import type CurrentUser from "discourse/models/user";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import I18n, { i18n } from "discourse-i18n";

// TODO(typescript-pending): drop once WelcomeBannerSearch is authored in .gts.
const WelcomeBannerSearch =
  WelcomeBannerSearchUntyped as unknown as ComponentLike<{
    Args: { translatedPlaceholder?: string };
  }>;

const HEADER_VARIABLES = "%{site_name}, %{preferred_display_name}";

interface WelcomeBannerSignature {
  Args: {
    /** Whether the banner carries the site search input. */
    showSearch?: boolean;
    /** Image filling the banner behind its text. */
    backgroundImage?: BlockImageValue;
    /** Headline for members on their first visit. */
    headerNewMembers?: string;
    /** Headline for returning members. */
    headerLoggedInMembers?: string;
    /** Headline for anonymous visitors. */
    headerAnonymousMembers?: string;
    /** Text below the headline for members. */
    subheaderLoggedInMembers?: string;
    /** Text below the headline for anonymous visitors. */
    subheaderAnonymousMembers?: string;
    /** Placeholder for the search input. */
    searchPlaceholder?: string;
  };
}

/**
 * The welcome banner as a block: a greeting for the viewer, an optional search
 * input and an optional background image. Text left blank falls back to the
 * welcome banner's translations. A layout that places this block replaces the
 * setting-driven welcome banner across the site.
 */
@block(WELCOME_BANNER_BLOCK, {
  thumbnail: () => import("discourse/blocks/thumbnails/welcome-banner"),
  displayName: i18n("blocks.builtin.welcome_banner.name"),
  icon: "house",
  category: "community",
  description: i18n("blocks.builtin.welcome_banner.description"),
  args: {
    showSearch: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.welcome_banner.show_search"),
      },
    },
    backgroundImage: {
      type: "image",
      allowDark: true,
      allowResize: false,
      allowComposition: true,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: {
        label: i18n("blocks.builtin.welcome_banner.background_image"),
      },
    },
    headerNewMembers: {
      type: "string",
      ui: {
        group: i18n("blocks.builtin.welcome_banner.groups.text"),
        label: i18n("blocks.builtin.welcome_banner.header_new_members"),
        helpText: i18n("blocks.builtin.welcome_banner.variables", {
          variables: HEADER_VARIABLES,
        }),
        placeholder: I18n.lookup("welcome_banner.header.new_members"),
      },
    },
    headerLoggedInMembers: {
      type: "string",
      ui: {
        group: i18n("blocks.builtin.welcome_banner.groups.text"),
        label: i18n("blocks.builtin.welcome_banner.header_logged_in_members"),
        helpText: i18n("blocks.builtin.welcome_banner.variables", {
          variables: HEADER_VARIABLES,
        }),
        placeholder: I18n.lookup("welcome_banner.header.logged_in_members"),
      },
    },
    headerAnonymousMembers: {
      type: "string",
      ui: {
        group: i18n("blocks.builtin.welcome_banner.groups.text"),
        label: i18n("blocks.builtin.welcome_banner.header_anonymous_members"),
        helpText: i18n("blocks.builtin.welcome_banner.variable", {
          variable: "%{site_name}",
        }),
        placeholder: I18n.lookup("welcome_banner.header.anonymous_members"),
      },
    },
    subheaderLoggedInMembers: {
      type: "string",
      ui: {
        control: "textarea",
        group: i18n("blocks.builtin.welcome_banner.groups.text"),
        label: i18n(
          "blocks.builtin.welcome_banner.subheader_logged_in_members"
        ),
        helpText: i18n(
          "blocks.builtin.welcome_banner.subheader_logged_in_members_help"
        ),
      },
    },
    subheaderAnonymousMembers: {
      type: "string",
      ui: {
        control: "textarea",
        group: i18n("blocks.builtin.welcome_banner.groups.text"),
        label: i18n(
          "blocks.builtin.welcome_banner.subheader_anonymous_members"
        ),
        helpText: i18n(
          "blocks.builtin.welcome_banner.subheader_anonymous_members_help"
        ),
      },
    },
    searchPlaceholder: {
      type: "string",
      ui: {
        group: i18n("blocks.builtin.welcome_banner.groups.text"),
        label: i18n("blocks.builtin.welcome_banner.search_placeholder"),
        helpText: i18n("blocks.builtin.welcome_banner.search_placeholder_help"),
        placeholder: I18n.lookup("welcome_banner.search_placeholder"),
        conditional: { arg: "showSearch", equals: true },
      },
    },
  },
})
export default class WelcomeBanner extends Component<WelcomeBannerSignature> {
  @service declare currentUser: CurrentUser | null;
  @service declare site: Site & { can_search?: boolean };
  @service declare siteSettings: { title?: string };

  get headerText() {
    const text = {
      new_members: this.args.headerNewMembers,
      logged_in_members: this.args.headerLoggedInMembers,
      anonymous_members: this.args.headerAnonymousMembers,
    }[welcomeBannerAudience(this.currentUser)];

    return welcomeBannerHeader({
      currentUser: this.currentUser,
      siteTitle: this.siteSettings.title,
      text: text?.trim(),
    });
  }

  get subheaderText() {
    const text = this.currentUser
      ? this.args.subheaderLoggedInMembers
      : this.args.subheaderAnonymousMembers;

    return welcomeBannerSubheader({
      currentUser: this.currentUser,
      siteTitle: this.siteSettings.title,
      text: text?.trim(),
    });
  }

  get showSearch() {
    return this.args.showSearch !== false && this.site.can_search;
  }

  get searchPlaceholder() {
    return (
      this.args.searchPlaceholder?.trim() ||
      i18n("welcome_banner.search_placeholder")
    );
  }

  <template>
    <div
      class={{dConcatClass
        "d-block-welcome-banner"
        (if @backgroundImage.url "--with-bg-img")
      }}
    >
      <div
        class="d-block-welcome-banner__backdrop"
        data-block-arg="backgroundImage"
        data-drop-passive
      >
        {{#if @backgroundImage.url}}
          <BlockImage @fill={{true}} @image={{@backgroundImage}} />
        {{/if}}
      </div>
      <div class="welcome-banner__wrap d-block-welcome-banner__content">
        <div class="welcome-banner__title">
          {{trustHTML this.headerText}}
          {{#if this.subheaderText}}
            <p class="welcome-banner__subheader">
              {{trustHTML this.subheaderText}}
            </p>
          {{/if}}
        </div>
        {{#if this.showSearch}}
          <WelcomeBannerSearch
            @translatedPlaceholder={{this.searchPlaceholder}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
