import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { action } from "@ember/object";
import type { ComponentLike } from "@glint/template";
import { block } from "discourse/blocks";
import BlockImage from "discourse/blocks/block-image";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dFit from "discourse/ui-kit/modifiers/d-fit";
import { i18n } from "discourse-i18n";
import { type CardArgs, cardArgs, validateCard } from "../-internals/card-args";
import { inlineText } from "../-internals/inline-text";

interface CardSignature {
  Args: CardArgs;
  Element: HTMLDivElement;
}

interface CardRegionSignature {
  Args: {
    /** Owning leaf; regions do not register as authored blocks. */
    card: Card;
  };
}

const CardIdentity: TOC<CardRegionSignature> = <template>
  <div class={{dConcatClass "d-block-card__identity" @card.identityClass}}>
    {{#if @card.showAvatar}}
      <div class="d-block-card__avatar" data-block-arg="avatar">
        {{#if @card.args.avatar.url}}
          <BlockImage @alt="" @fill={{true}} @image={{@card.args.avatar}} />
        {{/if}}
      </div>
    {{else if @card.showInitials}}
      <span
        aria-hidden="true"
        class="d-block-card__avatar"
      >{{@card.initials}}</span>
    {{/if}}
    <div class="d-block-card__identity-copy">
      {{#if @card.showIdentityName}}
        <RichTextRenderer
          @arg="identityName"
          @placeholder={{i18n "blocks.builtin.card.identity_name"}}
          @schema="plain"
          @value={{@card.args.identityName}}
          as |R|
        >
          <div class="d-block-card__identity-name"><R.Content /></div>
        </RichTextRenderer>
      {{/if}}
      {{#if @card.showIdentityRole}}
        <RichTextRenderer
          @arg="identityRole"
          @placeholder={{i18n "blocks.builtin.card.identity_role"}}
          @schema="plain"
          @value={{@card.args.identityRole}}
          as |R|
        >
          <div class="d-block-card__identity-role"><R.Content /></div>
        </RichTextRenderer>
      {{/if}}
    </div>
  </div>
</template>;

const CardLabel: TOC<CardRegionSignature> = <template>
  <div
    class={{dConcatClass "d-block-card__label" (if @card.badgeLabel "--badge")}}
  >
    {{#if @card.labelIcon}}
      <span
        class={{dConcatClass "d-block-card__icon" (if @card.tileIcon "--tile")}}
        data-block-arg="icon"
      >{{dIcon @card.args.icon}}</span>
    {{/if}}
    {{#if @card.showEyebrow}}
      <RichTextRenderer
        @arg="eyebrow"
        @schema="plain"
        @value={{@card.args.eyebrow}}
        as |R|
      ><R.Content /></RichTextRenderer>
    {{/if}}
  </div>
</template>;

const CardMedia: TOC<CardRegionSignature> = <template>
  <div
    class={{dConcatClass
      "d-block-card__media"
      (if @card.mediaIdentity "--identity")
      (if @card.photoIdentity "--photo")
    }}
  >
    <div
      class="d-block-card__image"
      data-block-arg="image"
      data-drop-passive={{if @card.mediaIsBackground ""}}
    >
      {{#if @card.args.image.url}}
        <BlockImage
          @alt={{@card.imageAlt}}
          @fill={{true}}
          @image={{@card.args.image}}
        />
      {{/if}}
    </div>
    {{#if @card.mediaIdentity}}<CardIdentity @card={{@card}} />{{/if}}
    {{#if @card.mediaLabel}}<CardLabel @card={{@card}} />{{/if}}
  </div>
</template>;

/** A single editable leaf with fixed media, content, identity and action regions. */
@block("card", {
  thumbnail: () => import("discourse/blocks/thumbnails/card"),
  displayName: "Card",
  icon: "id-card",
  category: "actions",
  description: "Static content with optional media, identity and actions.",
  args: cardArgs,
  validate: validateCard,
})
export default class Card extends Component<CardSignature> {
  @tracked _wideEnoughForBeside = false;

  get isEditing(): boolean {
    return debugHooks.isEditPresentation;
  }

  get presentation(): string {
    if (
      this.args.presentation === "none" ||
      (!this.args.image?.url && !this.isEditing)
    ) {
      return "none";
    }
    if (this.args.presentation === "beside" && !this._wideEnoughForBeside) {
      return "above";
    }
    return this.args.presentation ?? "above";
  }

  get className(): string {
    return dConcatClass(
      "d-block-card",
      `--${this.presentation}`,
      `--surface-${this.args.surface ?? "default"}`,
      `--scale-${this.args.scale ?? "standard"}`,
      this.args.imageWidth === "even" && "--even",
      this.args.imageSide === "end" && "--media-end",
      this.args.actionLayout === "inline" && "--inline-actions",
      this.args.dividers && "--dividers",
      this.isEditing && "is-editing"
    );
  }

  get headingTag(): ComponentLike<{
    Element: HTMLHeadingElement;
    Blocks: { default: [] };
  }> {
    const level = this.args.headingLevel ?? 3;
    return dElement(
      `h${Number.isInteger(level) && level >= 2 && level <= 6 ? level : 3}`
    ) as ComponentLike<{
      Element: HTMLHeadingElement;
      Blocks: { default: [] };
    }>;
  }

  get imageAlt(): string {
    return this.args.imageDecorative === false
      ? (this.args.imageAlt ?? "")
      : "";
  }

  get mediaAfterContent(): boolean {
    return (
      this.presentation === "below" ||
      (this.presentation === "beside" && this.args.imageSide === "end")
    );
  }

  get mediaIsBackground(): boolean {
    return (
      this.presentation === "behind" || this.mediaIdentity || this.mediaLabel
    );
  }

  get measureBeside(): boolean {
    return this.args.presentation === "beside";
  }

  get showMedia(): boolean {
    return this.presentation !== "none";
  }

  get identityClass(): string {
    return dConcatClass(
      `--${this.args.identityFormat ?? "compact"}`,
      this.args.identityShape === "rounded" && "--rounded"
    );
  }

  get initials(): string {
    return inlineText(this.args.identityName)
      .split(/\s+/u)
      .filter(Boolean)
      .slice(0, 2)
      .map((word) => Array.from(word)[0])
      .join("")
      .toLocaleUpperCase();
  }

  get showAvatar(): boolean {
    return (
      (this.args.avatarDisplay ?? "image") === "image" &&
      (Boolean(this.args.avatar?.url) || this.isEditing)
    );
  }

  get showInitials(): boolean {
    return this.args.avatarDisplay === "initials" && Boolean(this.initials);
  }

  get showIdentity(): boolean {
    return Boolean(
      this.args.identityEnabled &&
      (inlineText(this.args.identityName) || this.isEditing)
    );
  }

  get showIdentityName(): boolean {
    return Boolean(inlineText(this.args.identityName) || this.isEditing);
  }

  get showIdentityRole(): boolean {
    return Boolean(inlineText(this.args.identityRole) || this.isEditing);
  }

  get mediaIdentity(): boolean {
    return (
      this.showIdentity &&
      Boolean(this.args.image?.url) &&
      this.args.identityPlacement === "media" &&
      ["above", "below"].includes(this.presentation)
    );
  }

  get contentIdentity(): boolean {
    return this.showIdentity && !this.mediaIdentity;
  }

  get photoIdentity(): boolean {
    return this.mediaIdentity && this.args.identityTreatment === "photo";
  }

  get badgeLabel(): boolean {
    return this.args.labelStyle === "badge";
  }

  get labelIcon(): boolean {
    return Boolean(this.args.icon && this.args.iconTarget === "label");
  }

  get tileIcon(): boolean {
    return this.args.iconStyle === "tile";
  }

  get titleIcon(): boolean {
    return Boolean(this.args.icon && this.args.iconTarget !== "label");
  }

  get showEyebrow(): boolean {
    return Boolean(inlineText(this.args.eyebrow));
  }

  get showLabel(): boolean {
    return this.showEyebrow || this.labelIcon;
  }

  get mediaLabel(): boolean {
    return (
      this.showLabel &&
      this.args.labelPlacement === "media" &&
      this.presentation === "behind"
    );
  }

  get contentLabel(): boolean {
    return this.showLabel && !this.mediaLabel;
  }

  get showTitle(): boolean {
    return Boolean(inlineText(this.args.title) || this.isEditing);
  }

  get showHeading(): boolean {
    return this.showTitle || this.titleIcon;
  }

  get showMeta(): boolean {
    return Boolean(inlineText(this.args.meta) || this.isEditing);
  }

  get showBody(): boolean {
    return Boolean(inlineText(this.args.body) || this.isEditing);
  }

  get showCopy(): boolean {
    return (
      this.showTitle ||
      this.showMeta ||
      this.showBody ||
      this.titleIcon ||
      this.contentLabel ||
      this.contentIdentity
    );
  }

  get showContent(): boolean {
    return this.showCopy || this.showActions;
  }

  get primaryLabel(): string {
    return this.args.actionLabel?.trim() ?? "";
  }

  get primaryHref(): string | undefined {
    return this.args.href?.trim() || undefined;
  }

  get showPrimary(): boolean {
    return Boolean(this.primaryHref && this.primaryLabel);
  }

  get showSecondary(): boolean {
    return Boolean(
      this.args.secondaryEnabled &&
      this.args.secondaryHref?.trim() &&
      this.args.secondaryLabel?.trim()
    );
  }

  get showActions(): boolean {
    return this.showPrimary || this.showSecondary;
  }

  get wholeCardName(): string {
    return this.args.linkLabel?.trim() || inlineText(this.args.title);
  }

  get showInvisibleLink(): boolean {
    return Boolean(
      this.args.wholeCard &&
      this.primaryHref &&
      !this.showPrimary &&
      this.wholeCardName
    );
  }

  get buttonActions(): boolean {
    return this.args.actionStyle === "button";
  }

  computeBesideFit(width: number): boolean {
    return (
      width >=
      30 * parseFloat(getComputedStyle(document.documentElement).fontSize)
    );
  }

  @action
  updateBesideFit(wideEnough: boolean): void {
    this._wideEnoughForBeside = wideEnough;
  }

  <template>
    <div
      class={{this.className}}
      data-card-presentation={{this.presentation}}
      ...attributes
      {{dFit
        this.computeBesideFit
        active=this.measureBeside
        onChange=this.updateBesideFit
      }}
    >
      {{#if this.showMedia}}
        {{#unless this.mediaAfterContent}}<CardMedia
            @card={{this}}
          />{{/unless}}
      {{/if}}
      {{#if this.showContent}}
        <div class="d-block-card__content">
          {{#if this.showCopy}}
            <div class="d-block-card__copy">
              {{#if this.contentLabel}}<CardLabel @card={{this}} />{{/if}}
              {{#if this.contentIdentity}}<CardIdentity @card={{this}} />{{/if}}
              {{#if this.showHeading}}
                <div class="d-block-card__heading">
                  {{#if this.titleIcon}}
                    <span
                      class={{dConcatClass
                        "d-block-card__icon"
                        (if this.tileIcon "--tile")
                      }}
                      data-block-arg="icon"
                    >{{dIcon @icon}}</span>
                  {{/if}}
                  {{#if this.showTitle}}
                    <RichTextRenderer
                      @arg="title"
                      @placeholder={{i18n
                        "blocks.builtin.placeholders.card_title"
                      }}
                      @schema="paragraph"
                      @value={{@title}}
                      as |R|
                    >
                      <this.headingTag class="d-block-card__title"><R.Content
                        /></this.headingTag>
                    </RichTextRenderer>
                  {{/if}}
                </div>
              {{/if}}
              {{#if this.showMeta}}
                <RichTextRenderer
                  @arg="meta"
                  @placeholder={{i18n "blocks.builtin.placeholders.card_meta"}}
                  @schema="plain"
                  @value={{@meta}}
                  as |R|
                >
                  <div
                    class={{dConcatClass
                      "d-block-card__meta"
                      (if R.isEmpty "--empty")
                    }}
                  ><R.Content /></div>
                </RichTextRenderer>
              {{/if}}
              {{#if this.showBody}}
                <RichTextRenderer
                  @arg="body"
                  @placeholder={{i18n "blocks.builtin.placeholders.card_body"}}
                  @schema="paragraph"
                  @value={{@body}}
                  as |R|
                >
                  <p
                    class={{dConcatClass
                      "d-block-card__text"
                      (if R.isEmpty "--empty")
                    }}
                  ><R.Content /></p>
                </RichTextRenderer>
              {{/if}}
            </div>
          {{/if}}
          {{#if this.showActions}}
            <div class="d-block-card__actions">
              {{#if this.showPrimary}}
                <a
                  class={{dConcatClass
                    "d-block-card__primary"
                    (if @wholeCard "d-block-stretched-link")
                    (if this.buttonActions "btn btn-primary")
                  }}
                  data-block-arg="href"
                  href={{this.primaryHref}}
                  rel={{if @external "noopener noreferrer"}}
                  target={{if @external "_blank"}}
                >
                  {{this.primaryLabel}}
                </a>
              {{/if}}
              {{#if this.showSecondary}}
                <a
                  class={{dConcatClass
                    "d-block-card__secondary"
                    (if this.buttonActions "btn btn-default")
                  }}
                  data-block-arg="secondaryHref"
                  href={{@secondaryHref}}
                  rel={{if @secondaryExternal "noopener noreferrer"}}
                  target={{if @secondaryExternal "_blank"}}
                >
                  {{@secondaryLabel}}
                </a>
              {{/if}}
            </div>
          {{/if}}
        </div>
      {{/if}}
      {{#if this.showMedia}}
        {{#if this.mediaAfterContent}}<CardMedia @card={{this}} />{{/if}}
      {{/if}}
      {{#if this.showInvisibleLink}}
        <a
          aria-label={{this.wholeCardName}}
          class="d-block-stretched-link"
          data-block-arg="href"
          href={{this.primaryHref}}
          rel={{if @external "noopener noreferrer"}}
          target={{if @external "_blank"}}
        ></a>
      {{/if}}
    </div>
  </template>
}
