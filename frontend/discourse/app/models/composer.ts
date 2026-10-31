import { tracked } from "@glimmer/tracking";
import EmberObject, { computed, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { next, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { isHTMLSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { on } from "@ember-decorators/object";
import { Promise } from "rsvp";
import type DialogService from "discourse/dialog-holder/services/dialog";
import type { AjaxError } from "discourse/lib/ajax";
import { extractError, throwAjaxError } from "discourse/lib/ajax-error";
import { tinyAvatar } from "discourse/lib/avatar-utils";
import deprecated from "discourse/lib/deprecated";
import { QUOTE_REGEXP } from "discourse/lib/quote";
import { serializeTags } from "discourse/lib/serialize-tags";
import { prioritizeNameFallback } from "discourse/lib/settings";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import { emailValid, escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Draft from "discourse/models/draft";
import type Post from "discourse/models/post";
import RestModel, {
  type RestModelAttrs,
  type RestModelClass,
  type RestModelSaveResult,
  type RestPayload,
} from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic, { type TopicBasicUser } from "discourse/models/topic";
import User from "discourse/models/user";
import type AppEventsService from "discourse/services/app-events";
import { i18n } from "discourse-i18n";

/** Plugins may supply additional customization names and arbitrary transformed values. */
export type ComposerCustomizations = Record<
  string,
  (composer: Composer) => unknown
>;

export type ComposerState =
  | "closed"
  | "saving"
  | "open"
  | "draft"
  | "fullscreen";
export type ComposerTags = (
  | string
  | { id?: number; name: string; slug?: string; isNew?: boolean }
)[];
export type ComposerReplyToUser = {
  id?: number;
  username: string;
  name?: string | null;
  avatar_template: string;
};
export type ComposerImageSizes = Record<
  string,
  { width: number; height: number }
>;
/** Both plain plugin metadata and EmberObject metadata are serialized by enumerable key. */
export type ComposerMetaData = Record<string, unknown> | EmberObject;
export interface ComposerSaveOptions {
  imageSizes?: ComposerImageSizes;
  editReason?: string | null;
}

/** Runtime-assigned data; plugins augment this interface with their own fields. */
export interface ComposerFields {
  action?: string;
  draftKey?: string;
  draftSequence?: number;
  targetRecipients?: string;
  title?: string | null;
  tags?: ComposerTags;
  originalText?: string | null;
  originalTitle?: string | null;
  originalTags?: ComposerTags | null;
  featuredLink?: string | null;
  metaData?: ComposerMetaData | null;
  adminOnboardingTopicOption?: string | null;
  typingTime?: number;
  composerTotalOpened?: number;
  composerOpened?: Date | null;
  loading?: boolean;
  disableDrafts?: boolean;
  editConflict?: boolean;
  editReason?: string | null;
  stagedPost?: Post | false;
  createdPost?: Post;
  draftStatus?: string | null;
  draftConflictUser?: TopicBasicUser | null;
  isWarning?: boolean;
  hasTargetGroups?: boolean;
  warningsDisabled?: boolean;
  formTemplateId?: number;
  composerHeight?: string | number;
  _hasTopicTemplates?: boolean;
}

/** Draft restoration and plugins may pass additional serialized keys unchanged. */
export interface ComposerOpenOptions {
  action?: string;
  draftKey?: string;
  draftSequence?: number | null;
  composerState?: ComposerState;
  /** The post being edited or replied to. */
  post?: Post | null;
  /** The topic being edited or replied to. */
  topic?: Topic | null;
  postId?: number;
  /** Establishes both reply text and its baseline when replying from a quote. */
  quote?: string;
  reply?: string | null;
  title?: string | null;
  recipients?: string;
  /** Deprecated in favor of recipients. */
  usernames?: string;
  composerTime?: number;
  typingTime?: number;
  whisper?: boolean;
  noBump?: boolean;
  /** A site archetype, such as regular or private_message. */
  archetypeId?: string;
  metaData?: ComposerMetaData | null;
  categoryId?: number | null;
  topicCategoryId?: number | null | false;
  readOnlyCategoryId?: number | null;
  destinationCategoryId?: number;
  tags?: ComposerTags;
  originalText?: string | null;
  originalTitle?: string | null;
  originalTags?: ComposerTags | null;
  /** These draft keys are not the camelCase baselines read by _open. */
  original_text?: string | null;
  original_title?: string | null;
  original_tags?: ComposerTags | null;
  adminOnboardingTopicOption?: string | null;
  reply_to_post_number?: number | null;
  reply_to_user?: ComposerReplyToUser | null;
  [key: string]: unknown;
}

/** TODO(typescript-pending): Archetype field forwarders omit id; remove when Archetype declares its fields. */
type ComposerArchetype = NonNullable<Site["archetypes"]>[number] & {
  id: string;
};
/** TODO(typescript-pending): TopicDetails field forwarders omit edit permissions; remove when TopicDetails declares them. */
type ComposerTopicDetails = Topic["details"] & {
  can_edit?: boolean;
  can_edit_tags?: boolean;
};

type TextOptions = { block?: boolean; space?: boolean; new_line?: boolean };

let _customizations: ComposerCustomizations[] = [];

export function registerCustomizationCallback(cb: ComposerCustomizations) {
  _customizations.push(cb);
}

export function resetComposerCustomizations() {
  _customizations = [];
}

/** The actions the composer can take. */
export const CREATE_TOPIC = "createTopic" as const,
  CREATE_SHARED_DRAFT = "createSharedDraft" as const,
  EDIT_SHARED_DRAFT = "editSharedDraft" as const,
  PRIVATE_MESSAGE = "privateMessage" as const,
  REPLY = "reply" as const,
  EDIT = "edit" as const,
  NEW_PRIVATE_MESSAGE_KEY = "new_private_message" as const,
  NEW_TOPIC_KEY = "new_topic" as const,
  EDIT_TOPIC_KEY = "topic_" as const,
  ADD_TRANSLATION = "add_translation" as const;

function isEdit(action: string | undefined) {
  return action === EDIT || action === EDIT_SHARED_DRAFT;
}

const CLOSED = "closed",
  SAVING = "saving",
  OPEN = "open",
  DRAFT = "draft",
  FULLSCREEN = "fullscreen",
  // When creating, these fields are moved into the post model from the composer model
  _create_serializer: Record<string, string> = {
    raw: "reply",
    title: "title",
    unlist_topic: "unlistTopic",
    category: "categoryId",
    topic_id: "topic.id",
    is_warning: "isWarning",
    whisper: "whisper",
    archetype: "archetypeId",
    target_recipients: "targetRecipients",
    typing_duration_msecs: "typingTime",
    composer_open_duration_msecs: "composerTime",
    composer_version: "composerVersion",
    tags: "tags",
    featured_link: "featuredLink",
    shared_draft: "sharedDraft",
    no_bump: "noBump",
    draft_key: "draftKey",
    locale: "locale",
  },
  _update_serializer: Record<string, string> = {
    raw: "reply",
    topic_id: "topic.id",
    original_text: "originalText",
    locale: "locale",
  },
  _edit_topic_serializer: Record<string, string> = {
    title: "topic.title",
    categoryId: "topic.category.id",
    tags: "topic.tags",
    featuredLink: "topic.featured_link",
    original_title: "originalTitle",
    original_tags: "originalTags",
    locale: "locale",
  },
  _draft_serializer: Record<string, string> = {
    reply: "reply",
    action: "action",
    title: "title",
    categoryId: "categoryId",
    tags: "tags",
    archetypeId: "archetypeId",
    whisper: "whisper",
    metaData: "metaData",
    adminOnboardingTopicOption: "adminOnboardingTopicOption",
    composerTime: "composerTime",
    typingTime: "typingTime",
    postId: "post.id",
    recipients: "targetRecipients",
    original_text: "originalText",
    original_title: "originalTitle",
    original_tags: "originalTags",
    locale: "locale",
    reply_to_post_number: "reply_to_post_number",
    reply_to_user: "reply_to_user",
  },
  _add_draft_fields: Record<string, string> = {},
  FAST_REPLY_LENGTH_THRESHOLD = 10000;

export const SAVE_LABELS: Record<string, string> = {
  [EDIT]: "composer.save_edit",
  [REPLY]: "composer.reply",
  [CREATE_TOPIC]: "composer.create_topic",
  [PRIVATE_MESSAGE]: "composer.create_pm",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.save_edit",
  [ADD_TRANSLATION]: "composer.translations.save",
};

export const SAVE_ICONS: Record<string, string> = {
  [EDIT]: "pencil",
  [EDIT_SHARED_DRAFT]: "far-clipboard",
  [REPLY]: "reply",
  [CREATE_TOPIC]: "far-pen-to-square",
  [PRIVATE_MESSAGE]: "envelope",
  [CREATE_SHARED_DRAFT]: "far-clipboard",
};

/** Declares assigned data without emitting own properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Composer extends ComposerFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Composer extends RestModel {
  // The status the compose view can have
  static CLOSED: typeof CLOSED = CLOSED;
  static SAVING: typeof SAVING = SAVING;
  static OPEN: typeof OPEN = OPEN;
  static DRAFT: typeof DRAFT = DRAFT;
  static FULLSCREEN: typeof FULLSCREEN = FULLSCREEN;

  // The actions the composer can take
  static CREATE_TOPIC: typeof CREATE_TOPIC = CREATE_TOPIC;
  static CREATE_SHARED_DRAFT: typeof CREATE_SHARED_DRAFT = CREATE_SHARED_DRAFT;
  static EDIT_SHARED_DRAFT: typeof EDIT_SHARED_DRAFT = EDIT_SHARED_DRAFT;
  static PRIVATE_MESSAGE: typeof PRIVATE_MESSAGE = PRIVATE_MESSAGE;
  static REPLY: typeof REPLY = REPLY;
  static EDIT: typeof EDIT = EDIT;
  static ADD_TRANSLATION: typeof ADD_TRANSLATION = ADD_TRANSLATION;

  // Draft key
  static NEW_PRIVATE_MESSAGE_KEY: typeof NEW_PRIVATE_MESSAGE_KEY =
    NEW_PRIVATE_MESSAGE_KEY;
  static NEW_TOPIC_KEY: typeof NEW_TOPIC_KEY = NEW_TOPIC_KEY;
  static EDIT_TOPIC_KEY: typeof EDIT_TOPIC_KEY = EDIT_TOPIC_KEY;

  /** TODO: Replace with injection. */
  static override create<C extends RestModelClass>(
    this: C,
    args?: RestModelAttrs<InstanceType<C>>
  ): InstanceType<C>;

  static override create(args?: RestPayload) {
    args = args || {};
    args.user = args.user || User.current();
    args.site = args.site || Site.current();
    return super.create(args);
  }

  static serializeToTopic(fieldName: string, property?: string) {
    if (!property) {
      property = fieldName;
    }
    _edit_topic_serializer[fieldName] = property;
  }

  static serializeOnCreate(fieldName: string, property?: string) {
    if (!property) {
      property = fieldName;
    }
    _create_serializer[fieldName] = property;
  }

  static serializedFieldsForCreate() {
    return Object.keys(_create_serializer);
  }

  static serializeOnUpdate(fieldName: string, property?: string) {
    if (!property) {
      property = fieldName;
    }
    _update_serializer[fieldName] = property;
  }

  static serializedFieldsForUpdate() {
    return Object.keys(_update_serializer);
  }

  static serializeToDraft(fieldName: string, property?: string) {
    if (!property) {
      property = fieldName;
    }
    _draft_serializer[fieldName] = property;
    _add_draft_fields[fieldName] = property;
  }

  static serializedFieldsForDraft() {
    return Object.keys(_draft_serializer);
  }

  static isEditDraft(draft?: { action?: string; postId?: number } | null) {
    return isEdit(draft?.action) && !!draft.postId;
  }

  @service dialog!: DialogService;
  @service declare siteSettings: RestModel["siteSettings"];
  @service currentUser!: User | null;

  @tracked topic: Topic | null | undefined;
  @tracked post?: Post | null;

  @tracked reply: string | null | undefined;
  @tracked whisper: boolean | undefined;
  @tracked reply_to_post_number: number | null = null;
  @tracked reply_to_user: ComposerReplyToUser | null = null;

  /** Reads injected settings during construction, before create attributes are assigned. */
  @tracked
  locale: string | null | undefined = (this as Composer).siteSettings
    .content_localization_enabled
    ? this.post?.locale
    : null;

  @tracked unlistTopic = false;
  declare appEvents: AppEventsService;

  /** TODO(typescript-pending): MessageBusService.create returns any; use its clientId contract when the factory is typed. */
  declare messageBus: { clientId: string };
  noBump: boolean | undefined = false;
  draftSaving = false;
  draftForceSave = false;
  showFullScreenExitPrompt = false;

  @tracked _categoryId: number | null = null;

  @tracked _archetypesOverride: ComposerArchetype[] | undefined;

  @tracked _user!: User | null;

  @tracked _composeState: ComposerState | undefined;

  @tracked _archetypeId: string | undefined;

  @dependentKeyCompat
  get composeState() {
    return this._composeState;
  }

  set composeState(value: ComposerState | undefined) {
    if (value === this._composeState) {
      return;
    }
    this._composeState = value;
    this.composeStateChanged();
  }

  @dependentKeyCompat
  get archetypeId() {
    return this._archetypeId;
  }

  set archetypeId(value: string | undefined) {
    if (value === this._archetypeId) {
      return;
    }
    this._archetypeId = value;
    this.set("metaData", EmberObject.create());
  }

  @dependentKeyCompat
  get user() {
    return applyValueTransformer("composer-user", this._user, {
      composer: this,
    });
  }

  set user(value: User | null) {
    this._user = value;
  }

  @computed("site.archetypes")
  get archetypes(): ComposerArchetype[] | undefined {
    if (this._archetypesOverride !== undefined) {
      return this._archetypesOverride;
    }
    return this.site?.archetypes as ComposerArchetype[] | undefined;
  }

  set archetypes(value: ComposerArchetype[] | undefined) {
    this._archetypesOverride = value;
  }

  @dependentKeyCompat
  get categoryId(): number | null {
    return this._categoryId;
  }

  /** Applies topic templates with both the previous and new category. */
  set categoryId(categoryId: number | null | undefined) {
    const oldCategoryId = this._categoryId;

    if (this.privateMessage) {
      categoryId = null;
    } else if (isEmpty(categoryId)) {
      // Check if there is a default composer category to set
      const defaultComposerCategoryId = parseInt(
        // TODO(typescript-pending): settings values remain unknown until SiteSettingsService types its factory result.
        this.siteSettings.default_composer_category as string,
        10
      );
      categoryId =
        defaultComposerCategoryId && defaultComposerCategoryId > 0
          ? defaultComposerCategoryId
          : null;
    }
    // isEmpty handles undefined at runtime; Ember's predicate does not narrow its type.
    this._categoryId = categoryId!;

    if (oldCategoryId !== categoryId) {
      const applyTemplate = () => {
        this.applyTopicTemplate(oldCategoryId, categoryId);
        this.appEvents?.trigger("composer:category-changed", this);
      };

      if (this.site.lazy_load_categories) {
        Category.asyncFindById(categoryId!).then(applyTemplate);
      } else {
        applyTemplate();
      }
    }
  }

  @computed("action")
  get sharedDraft() {
    return this.action === CREATE_SHARED_DRAFT;
  }

  @computed("action")
  get creatingTopic() {
    return this.action === CREATE_TOPIC;
  }

  @computed("action")
  get creatingSharedDraft() {
    return this.action === CREATE_SHARED_DRAFT;
  }

  @computed("action")
  get creatingPrivateMessage() {
    return this.action === PRIVATE_MESSAGE;
  }

  @computed("creatingPrivateMessage")
  get notCreatingPrivateMessage() {
    return !this.creatingPrivateMessage;
  }

  @computed("privateMessage")
  get notPrivateMessage() {
    return !this.privateMessage;
  }

  @computed("creatingTopic", "editingFirstPost")
  get topicFirstPost() {
    return this.creatingTopic || this.editingFirstPost;
  }

  @computed("composeState")
  get viewOpen() {
    return this.composeState === OPEN;
  }

  @computed("composeState")
  get viewDraft() {
    return this.composeState === DRAFT;
  }

  @computed("composeState")
  get viewFullscreen() {
    return this.composeState === FULLSCREEN;
  }

  @computed("viewOpen", "viewFullscreen")
  get viewOpenOrFullscreen() {
    return this.viewOpen || this.viewFullscreen;
  }

  @computed("editingPost", "post.firstPost")
  get editingFirstPost() {
    return this.editingPost && this.post?.firstPost;
  }

  @computed(
    "creatingTopic",
    "creatingPrivateMessage",
    "editingFirstPost",
    "creatingSharedDraft"
  )
  get canEditTitle() {
    return (
      this.creatingTopic ||
      this.creatingPrivateMessage ||
      this.editingFirstPost ||
      this.creatingSharedDraft
    );
  }

  @computed("canEditTitle", "notCreatingPrivateMessage", "notPrivateMessage")
  get canCategorize() {
    return (
      this.canEditTitle &&
      this.notCreatingPrivateMessage &&
      this.notPrivateMessage
    );
  }

  @computed("reply", "originalText")
  get replyDirty() {
    return (this.reply || "").trim() !== (this.originalText || "").trim();
  }

  @computed("title", "originalTitle")
  get titleDirty() {
    return (this.title || "").trim() !== (this.originalTitle || "").trim();
  }

  @computed("replyDirty", "titleDirty", "canEditTitle", "hasMetaData")
  get anyDirty() {
    return (
      this.replyDirty ||
      (this.canEditTitle && this.titleDirty) ||
      this.hasMetaData
    );
  }

  @computed("categoryId")
  get category() {
    return this.categoryId ? Category.findById(this.categoryId) : null;
  }

  @dependentKeyCompat
  get replyingToTopic() {
    return this.get("action") === REPLY;
  }

  @dependentKeyCompat
  get editingPost() {
    return applyValueTransformer("composer-editing-post", isEdit(this.action), {
      composer: this,
    });
  }

  @computed("category.minimumRequiredTags")
  get minimumRequiredTags() {
    return this.category?.minimumRequiredTags || 0;
  }

  @computed("editingPost", "topic.details.can_edit")
  get disableTitleInput() {
    return (
      this.editingPost &&
      !(this.topic?.details as ComposerTopicDetails | undefined)?.can_edit
    );
  }

  @computed("privateMessage", "archetype.hasOptions")
  get showCategoryChooser() {
    const manyCategories =
      this.site.lazy_load_categories || this.site.categories.length > 1;
    return (
      !this.privateMessage && (this.archetype?.hasOptions || manyCategories)
    );
  }

  @computed("creatingPrivateMessage", "topic")
  get privateMessage() {
    return (
      this.creatingPrivateMessage ||
      (this.topic && this.topic.archetype === "private_message")
    );
  }

  get composerTime() {
    let total = this.composerTotalOpened || 0;
    const oldOpen = this.composerOpened;

    if (oldOpen) {
      // Date subtraction uses numeric coercion without changing the stored Date.
      total +=
        (new Date() as unknown as number) - (oldOpen as unknown as number);
    }

    return total;
  }

  get composerVersion(): 1 | 2 {
    if (this.currentUser!.useRichEditor) {
      return 2;
    }

    return 1;
  }

  @computed("archetypeId")
  get archetype() {
    return this.archetypes!.find(
      (archetype) => archetype.id === this.archetypeId
    );
  }

  @computed(
    "canEditTitle",
    "creatingPrivateMessage",
    "categoryId",
    "user.trust_level"
  )
  get canEditTopicFeaturedLink() {
    if (this.user?.trust_level === 0) {
      return false;
    }

    if (
      !this.siteSettings.topic_featured_link_enabled ||
      !this.canEditTitle ||
      this.creatingPrivateMessage
    ) {
      return false;
    }

    const categoryIds = this.site.topic_featured_link_allowed_category_ids;
    if (
      !this.categoryId &&
      categoryIds &&
      (categoryIds.includes(this.site.uncategorized_category_id!) ||
        !this.siteSettings.allow_uncategorized_topics)
    ) {
      return true;
    }
    return (
      categoryIds === undefined ||
      !categoryIds.length ||
      categoryIds.includes(this.categoryId!)
    );
  }

  @computed("canEditTopicFeaturedLink", "category")
  get titlePlaceholder() {
    const custom = this.customizationFor("titlePlaceholder");
    if (custom) {
      return custom;
    }

    if (this.canEditTopicFeaturedLink) {
      return "composer.title_or_link_placeholder";
    }
    return "composer.title_placeholder";
  }

  @computed("category.topic_title_placeholder")
  get categoryTitlePlaceholder() {
    return this.category?.topic_title_placeholder || null;
  }

  @computed("action", "post", "topic", "topic.title", "reply_to_user")
  get replyOptions() {
    const options: {
      userLink: { href: string; anchor: string } | null;
      topicLink: { href: string; anchor: string } | null;
      postLink: { href: string; anchor: string } | null;
      userAvatar: string | null;
      originalUser: { username: string; avatar: string } | null;
      label?: string;
    } = {
      userLink: null,
      topicLink: null,
      postLink: null,
      userAvatar: null,
      originalUser: null,
    };

    if (this.topic) {
      options.topicLink = {
        href: this.topic.url,
        anchor: this.topic.fancyTitle || escapeExpression(this.topic?.title),
      };
    }

    if (this.post) {
      options.label = i18n(`post.${this.action}`);
      const avatarTemplate = applyValueTransformer(
        "composer-reply-options-user-avatar-template",
        this.post.avatar_template,
        { post: this.post }
      );
      options.userAvatar = tinyAvatar(avatarTemplate);

      if (this.site.desktopView) {
        const originalUserName = this.reply_to_user?.username;
        const originalUserAvatar = this.reply_to_user?.avatar_template;
        if (originalUserName && originalUserAvatar && isEdit(this.action)) {
          options.originalUser = {
            username: originalUserName,
            avatar: tinyAvatar(originalUserAvatar),
          };
        }
      }
    }

    if (this.topic && this.post) {
      const postNumber = this.post.post_number;

      options.postLink = {
        href: `${this.topic.url}/${postNumber}`,
        anchor: i18n("post.post_number", { number: postNumber }),
      };

      const namePrioritized = prioritizeNameFallback(
        this.post.name,
        this.post.username
      );
      const name = applyValueTransformer(
        "composer-reply-options-user-link-name",
        namePrioritized,
        { post: this.post }
      );

      options.userLink = {
        href: `${this.topic.url}/${postNumber}`,
        anchor: name,
      };
    }

    return options;
  }

  @computed("targetRecipients")
  get targetRecipientsArray(): {
    type: "group" | "email" | "user";
    name: string;
  }[] {
    const recipients = this.targetRecipients
      ? this.targetRecipients.split(",")
      : [];
    const groups = new Set(this.site.groups.map((g) => g.name));

    return recipients.map((item) => {
      if (groups.has(item)) {
        return { type: "group", name: item };
      } else if (emailValid(item)) {
        return { type: "email", name: item };
      } else {
        return { type: "user", name: item };
      }
    });
  }

  /** The PM branch preserves an absent or empty recipients value. */
  @computed(
    "loading",
    "canEditTitle",
    "titleLength",
    "targetRecipients",
    "targetRecipientsArray",
    "replyLength",
    "categoryId",
    "missingReplyCharacters",
    "tags",
    "topicFirstPost",
    "minimumRequiredTags",
    "user.staff"
  )
  get cantSubmitPost() {
    // can't submit while loading
    if (this.loading) {
      return true;
    }

    // title is required when
    //  - creating a new topic/private message
    //  - editing the 1st post
    if (this.canEditTitle && !this.titleLengthValid) {
      return true;
    }

    // reply is always required
    if (this.missingReplyCharacters > 0) {
      return true;
    }

    if (
      this.site.can_tag_topics &&
      !this.user?.staff &&
      this.topicFirstPost &&
      this.minimumRequiredTags
    ) {
      const tagsArray = this.tags || [];
      if (tagsArray.length < this.minimumRequiredTags) {
        return true;
      }
    }

    if (this.topicFirstPost) {
      // user should modify topic template
      const category = this.category;
      if (category && category.topic_template) {
        if (this.reply!.trim() === category.topic_template.trim()) {
          this.dialog.alert(i18n("composer.error.topic_template_not_modified"));
          return true;
        }
      }
    }

    if (this.privateMessage) {
      // need at least one user when sending a PM
      return this.targetRecipients && this.targetRecipientsArray.length === 0;
    } else {
      // has a category? (when needed)
      return this.requiredCategoryMissing;
    }
  }

  @computed("canCategorize", "categoryId")
  get requiredCategoryMissing() {
    return (
      this.canCategorize &&
      !this.categoryId &&
      !this.siteSettings.allow_uncategorized_topics &&
      !!this._hasTopicTemplates
    );
  }

  @computed("minimumTitleLength", "titleLength", "post.static_doc")
  get titleLengthValid() {
    if (this.user!.admin && this.post?.static_doc && this.titleLength > 0) {
      return true;
    }
    if (this.titleLength < this.minimumTitleLength) {
      return false;
    }
    return (
      this.titleLength <= (this.siteSettings.max_topic_title_length as number)
    );
  }

  @computed("metaData")
  get hasMetaData() {
    return this.metaData ? !isEmpty(Object.keys(this.metaData)) : false;
  }

  @computed("minimumTitleLength", "titleLength")
  get missingTitleCharacters() {
    return this.minimumTitleLength - this.titleLength;
  }

  /** TODO(typescript-pending): numeric settings casts can go when SiteSettingsService types its factory result. */
  @computed("privateMessage")
  get minimumTitleLength() {
    if (this.privateMessage) {
      return this.siteSettings.min_personal_message_title_length as number;
    } else {
      return this.siteSettings.min_topic_title_length as number;
    }
  }

  @computed("minimumPostLength", "replyLength", "canEditTopicFeaturedLink")
  get missingReplyCharacters() {
    if (
      this.get("post.post_type") === this.site.get("post_types.small_action") ||
      (this.canEditTopicFeaturedLink && this.featuredLink)
    ) {
      return 0;
    }
    return this.minimumPostLength - this.replyLength;
  }

  @computed("privateMessage", "topicFirstPost", "topic.pm_with_non_human_user")
  get minimumPostLength() {
    let length;

    if (this.topic?.pm_with_non_human_user) {
      length = 1;
    } else if (this.privateMessage) {
      length = this.siteSettings.min_personal_message_post_length as number;
    } else if (this.topicFirstPost) {
      // first post (topic body)
      length = this.siteSettings.min_first_post_length as number;
    } else {
      length = this.siteSettings.min_post_length as number;
    }

    return applyValueTransformer("composer-minimum-post-length", length, {
      composer: this,
    });
  }

  @computed("title")
  get titleLength() {
    const title = this.title || "";
    if (isHTMLSafe(title)) {
      return title.toString().length;
    }
    return title.replace(/\s+/gim, " ").trim().length;
  }

  @computed("reply")
  get replyLength() {
    let reply = this.reply || "";

    if (reply.length > FAST_REPLY_LENGTH_THRESHOLD) {
      return reply.length;
    }

    const commentsRegexp = /<!--(.*?)-->/gm;
    while (commentsRegexp.test(reply)) {
      reply = reply.replace(commentsRegexp, "");
    }

    while (QUOTE_REGEXP.test(reply)) {
      // make it global so we can strip as many quotes at once
      // keep in mind nested quotes mean we still need a loop here
      const regex = new RegExp(QUOTE_REGEXP.source, "img");
      reply = reply.replace(regex, "");
    }

    // This is in place so we do not generate any intermediate
    // strings while calculating the length, this is issued
    // every keypress in the composer so it needs to be very fast
    let len = 0,
      skipSpace = true;

    for (let i = 0; i < reply.length; i++) {
      const code = reply.charCodeAt(i);

      let isSpace = false;
      if (code >= 0x2000 && code <= 0x200a) {
        isSpace = true;
      } else {
        switch (code) {
          case 0x09: // \t
          case 0x0a: // \n
          case 0x0b: // \v
          case 0x0c: // \f
          case 0x0d: // \r
          case 0x20:
          case 0xa0:
          case 0x1680:
          case 0x202f:
          case 0x205f:
          case 0x3000:
            isSpace = true;
        }
      }

      if (isSpace) {
        if (!skipSpace) {
          len++;
          skipSpace = true;
        }
      } else {
        len++;
        skipSpace = false;
      }
    }

    if (len > 0 && skipSpace) {
      len--;
    }

    return len;
  }

  @computed(
    "draftSaving",
    "disableDrafts",
    "canEditTitle",
    "title",
    "reply",
    "titleLengthValid",
    "replyLength",
    "minimumPostLength"
  )
  get canSaveDraft() {
    if (this.action === Composer.ADD_TRANSLATION) {
      return false;
    }

    if (this.draftSaving) {
      return false;
    }

    if (this.disableDrafts) {
      return false;
    }

    // Title is only edited when editing topic OP or making a new topic.
    if (this.canEditTitle) {
      if (isEmpty(this.title) && isEmpty(this.reply)) {
        return false;
      }
    } else {
      if (isEmpty(this.reply)) {
        return false;
      }
    }

    return true;
  }

  composeStateChanged() {
    const oldOpen = this.composerOpened;
    const elem = document.documentElement;

    if (this.composeState === FULLSCREEN) {
      elem.classList.add("fullscreen-composer");
    } else {
      elem.classList.remove("fullscreen-composer");
    }

    if (this.composeState === OPEN) {
      this.set("composerOpened", oldOpen || new Date());
      elem.classList.add("composer-open");
    } else {
      if (oldOpen) {
        const oldTotal = this.composerTotalOpened || 0;
        this.set(
          "composerTotalOpened",
          oldTotal +
            ((new Date() as unknown as number) - (oldOpen as unknown as number))
        );
      }
      this.set("composerOpened", null);
      elem.classList.remove("composer-open");
    }
  }

  // called whenever the user types to update the typing time
  typing() {
    throttle(
      this,
      function (this: Composer) {
        const typingTime = this.typingTime || 0;
        this.set("typingTime", typingTime + 100);
      },
      100,
      false
    );
  }

  appendText(text: string, position?: number | null, opts?: TextOptions) {
    const reply = this.reply || "";
    position = typeof position === "number" ? position : reply.length;

    let before = reply.slice(0, position) || "";
    let after = reply.slice(position) || "";

    let stripped, i;
    if (opts && opts.block) {
      if (before.trim() !== "") {
        stripped = before.replace(/\r/g, "");
        for (i = 0; i < 2; i++) {
          if (stripped[stripped.length - 1 - i] !== "\n") {
            before += "\n";
            position++;
          }
        }
      }
      if (after.trim() !== "") {
        stripped = after.replace(/\r/g, "");
        for (i = 0; i < 2; i++) {
          if (stripped[i] !== "\n") {
            after = "\n" + after;
          }
        }
      }
    }

    if (opts && opts.space) {
      if (before.length > 0 && !before[before.length - 1].match(/\s/)) {
        before = before + " ";
      }
      if (after.length > 0 && !after[0].match(/\s/)) {
        after = " " + after;
      }
    }

    if (opts && opts.new_line) {
      if (before.length > 0) {
        text = "\n\n" + text.trim();
      } else {
        text = text.trim();
      }
    }

    this.set("reply", before + text + after);

    return before.length + text.length;
  }

  prependText(text: string, opts?: TextOptions) {
    const reply = this.reply || "";

    if (opts && opts.new_line && reply.length > 0) {
      text = text.trim() + "\n\n";
    }

    this.set("reply", text + reply);
  }

  applyTopicTemplate(
    oldCategoryId: number | null | undefined,
    categoryId: number | null | undefined
  ) {
    applyBehaviorTransformer(
      "composer-apply-topic-template",
      () => {
        if (this.action !== CREATE_TOPIC) {
          return;
        }

        let reply = this.reply;

        // If the user didn't change the template, clear it
        if (oldCategoryId) {
          const oldCat = Category.findById(oldCategoryId);
          if (oldCat && oldCat.topic_template === reply) {
            reply = "";
          }
        }

        if (!isEmpty(reply)) {
          return;
        }

        const category = Category.findById(categoryId);
        if (category) {
          this.set("reply", category.topic_template || "");
          this.set("originalText", category.topic_template || "");
        }
      },
      { composer: this, oldCategoryId, categoryId }
    );
  }

  /** Opens a composer; plugins may override this method or transform its behavior. */
  open(opts?: ComposerOpenOptions | null) {
    if (!opts) {
      opts = {};
    }

    return applyBehaviorTransformer("composer-open", () => this._open(opts), {
      composer: this,
      opts,
    });
  }

  /** Override to run asynchronous logic before saving. */
  beforeSave() {
    return Promise.resolve();
  }

  /** Keeps the override assignable to RestModel while exposing the composer save result. */
  save(this: never, ...args: never[]): never;
  save(
    opts: ComposerSaveOptions
  ): Promise<RestModelSaveResult<Post> | undefined>;

  save(opts: ComposerSaveOptions) {
    return this.beforeSave().then(() => {
      if (!this.cantSubmitPost) {
        // change category may result in some effect for topic featured link
        if (!this.canEditTopicFeaturedLink) {
          this.set("featuredLink", null);
        }
        return this.editingPost ? this.editPost(opts) : this.createPost(opts);
      }
    });
  }

  clearState() {
    this.setProperties({
      originalText: null,
      originalTitle: null,
      originalTags: null,
      reply: null,
      post: null,
      title: null,
      unlistTopic: false,
      editReason: null,
      stagedPost: false,
      typingTime: 0,
      composerOpened: null,
      composerTotalOpened: 0,
      featuredLink: null,
      noBump: false,
      editConflict: false,
      reply_to_post_number: null,
      reply_to_user: null,
    });
  }

  setReplyTo(
    postNumber: number | null | undefined,
    user: ComposerReplyToUser | null | undefined
  ) {
    this.setProperties({
      reply_to_post_number: postNumber ?? null,
      reply_to_user: postNumber ? (user ?? null) : null,
    });
  }

  editPost(opts: ComposerSaveOptions) {
    this.set("composeState", SAVING);

    const post = this.post!;
    const oldCooked = post.cooked;
    let promise: Promise<unknown> = Promise.resolve();

    // Update the topic if we're editing the first post
    if (this.title && post.post_number === 1) {
      const topic = this.topic!;

      if ((topic.details as ComposerTopicDetails).can_edit) {
        const topicProps = this.getProperties(
          Object.keys(_edit_topic_serializer)
        );
        // user clicked "overwrite edits" button
        if (!this.editConflict) {
          topicProps.original_title = this.originalTitle;
          topicProps.original_tags = this.originalTags;
        }

        // frontend should have featuredLink but backend needs featured_link
        if (topicProps.featuredLink !== topic.featured_link) {
          topicProps.featured_link = topicProps.featuredLink ?? null;
        }
        delete topicProps.featuredLink;

        // If we're editing a shared draft, keep the original category
        if (this.action === EDIT_SHARED_DRAFT) {
          const destinationCategoryId = topicProps.categoryId;
          promise = promise.then(() =>
            topic.updateDestinationCategory(
              destinationCategoryId as number | null
            )
          );
          topicProps.categoryId = topic.get("category.id");
        }
        promise = promise.then(() => Topic.update(topic, topicProps));
      } else if ((topic.details as ComposerTopicDetails).can_edit_tags) {
        promise = promise.then(() => topic.updateTags(this.tags));
      }
    }

    // eslint-disable-next-line prefer-const
    let props: RestPayload = {
      edit_reason: opts.editReason,
      image_sizes: opts.imageSizes,
    };

    this.serialize(_update_serializer, props);

    // Only send when changed; otherwise a stale composer value could
    // clobber a concurrent reply-target change by another editor.
    if (this.reply_to_post_number !== (post?.reply_to_post_number ?? null)) {
      props.reply_to_post_number = this.reply_to_post_number;
    }

    // user clicked "overwrite edits" button
    if (this.editConflict) {
      delete props.original_text;
      delete props.original_title;
      delete props.original_tags;
    }

    const rollback = throwAjaxError(
      (error: { jqXHR?: { status?: number } }) => {
        post.setProperties({ cooked: oldCooked });
        this.set("composeState", OPEN);
        if (error.jqXHR && error.jqXHR.status === 409) {
          this.set("editConflict", true);
        }
      }
    );

    const cooked = this.getCookedHtml();
    post.setProperties({ cooked, staged: true });

    return promise
      .then(() => {
        return post.save(props).then((result) => {
          // The server omits `reply_to_user` from the response when it's
          // nil, so the post's in-memory value isn't overwritten when the
          // target is cleared. Mirror the composer's final state onto the
          // post so reply indicators update without a refresh.
          post.setProperties({
            reply_to_post_number: this.reply_to_post_number,
            reply_to_user: this.reply_to_user,
          });
          this.clearState();
          return result;
        });
      })
      .catch(rollback)
      .finally(() => {
        post.set("staged", false);
      });
  }

  serialize(
    serializer: Record<string, string>,
    dest?: RestPayload
  ): RestPayload;

  serialize<T extends object>(serializer: Record<string, string>, dest: T): T;
  serialize(serializer: Record<string, string>, dest?: object) {
    dest = dest || {};
    Object.keys(serializer).forEach((f) => {
      let val = this.get(serializer[f]);
      if (typeof val !== "undefined") {
        if (f === "tags" && Array.isArray(val)) {
          val = serializeTags(val);
        }
        set(dest, f, val);
      }
    });
    return dest;
  }

  async createPost(opts: ComposerSaveOptions) {
    if (CREATE_TOPIC === this.action || PRIVATE_MESSAGE === this.action) {
      this.set("topic", null);
    }

    const post = this.post;
    const topic = this.topic;
    // Saving requires an authenticated author, although a closed composer may have none.
    const user = this.user!;
    const postStream = this.get("topic.postStream") as
      | Topic["postStream"]
      | undefined;
    const postTypes = this.site.post_types!;
    const postType = this.whisper ? postTypes.whisper : postTypes.regular;

    // Build the post object
    const createdPost = this.store.createRecord("post", {
      imageSizes: opts.imageSizes,
      cooked: this.getCookedHtml(),
      reply_count: 0,
      name: user.name,
      display_username: user.name,
      username: user.username,
      user_id: user.id,
      user_title: user.title,
      avatar_template: user.avatar_template,
      user_custom_fields: user.custom_fields,
      post_type: postType,
      actions_summary: [],
      moderator: user.moderator,
      admin: user.admin,
      yours: true,
      read: true,
      wiki: false,
      typingTime: this.typingTime,
      composerTime: this.composerTime,
      metaData: this.metaData,
      locale: this.siteSettings.content_localization_enabled
        ? this.locale
        : null,
    });

    this.serialize(_create_serializer, createdPost);

    if (post) {
      createdPost.setProperties({
        reply_to_post_number: post.post_number,
        reply_to_user: post.getProperties("username", "avatar_template"),
      });
    }

    let state = null;

    // If we're in a topic, we can append the post instantly.
    if (postStream) {
      // If it's in reply to another post, increase the reply count
      post?.setProperties({
        reply_count: (post.reply_count || 0) + 1,
        replies: [],
      });

      // We do not stage posts in mobile view, we do not have the "cooked"
      // Furthermore calculating cooked is very complicated, especially since
      // we would need to handle oneboxes and other bits that are not even in the
      // engine, staging will just cause a blank post to render
      if (!isEmpty(createdPost.cooked)) {
        state = postStream.stagePost(createdPost, user);
        if (state === "alreadyStaging") {
          return;
        }
      }
    }

    this.setProperties({
      composeState: SAVING,
      stagedPost: state === "staged" && createdPost,
    });

    try {
      // TODO(typescript-pending): PostAdapter supplies these save members; remove when the adapter's result is typed.
      const result = (await createdPost.save()) as RestModelSaveResult<Post> & {
        responseJson: RestPayload & { action: string; post?: RestPayload };
        target: Post;
      };
      let saving = true;

      if (result.responseJson.action === "enqueued") {
        postStream?.undoPost(createdPost);
        this.set("composeState", CLOSED);
        return result;
      }

      // We sometimes want to hide the `reply_to_user` if the post contains a quote
      if (result.responseJson.post && !result.responseJson.post.reply_to_user) {
        createdPost.set("reply_to_user", null);
      }

      let addedToStream = false;
      if (topic) {
        // It's no longer a new post
        topic.set("draft_sequence", result.target.draft_sequence);
        postStream!.commitPost(createdPost);
        addedToStream = true;
      } else {
        // We created a new topic, let's show it.
        this.set("composeState", CLOSED);
        saving = false;

        // Update topic_count for the category
        // The serializer stores the category ID here; parseInt performs the existing numeric coercion.
        const postCategoryId =
          parseInt(createdPost.category as unknown as string, 10) || 1;
        const category = Category.findById(postCategoryId);

        category?.incrementProperty("topic_count");
      }

      this.clearState();
      this.set("createdPost", createdPost);

      if (this.replyingToTopic) {
        this.appEvents.trigger("post:created", createdPost);
      } else {
        this.appEvents.trigger("topic:created", createdPost, this);
      }

      if (addedToStream) {
        this.set("composeState", CLOSED);
      } else if (saving) {
        this.set("composeState", SAVING);
      }

      return result;
    } catch (error) {
      if (postStream) {
        postStream.undoPost(createdPost);

        post?.set("reply_count", post.reply_count! - 1);
      }

      next(() => this.set("composeState", OPEN));

      throw extractError(error);
    }
  }

  getCookedHtml() {
    const editorPreviewNode = document.querySelector(
      "#reply-control .d-editor-preview"
    );

    if (editorPreviewNode) {
      return editorPreviewNode.innerHTML.replace(
        /<span class="marker"><\/span>/g,
        ""
      );
    }

    return "";
  }

  serializeDraftData() {
    return this.serialize(_draft_serializer);
  }

  saveDraft() {
    if (!this.canSaveDraft) {
      return Promise.reject();
    }

    this.set("draftSaving", true);

    const draftSequence = this.draftSequence;
    this.set("draftSequence", this.draftSequence! + 1);

    return Draft.save(
      this.draftKey!,
      draftSequence!,
      this.serializeDraftData(),
      this.messageBus.clientId,
      { forceSave: this.draftForceSave }
    )
      .then((result) => {
        if ("draft_sequence" in result) {
          this.set("draftSequence", result.draft_sequence);
        }
        if (result.conflict_user) {
          this.setProperties({
            draftStatus: i18n("composer.edit_conflict"),
            draftConflictUser: result.conflict_user,
          });
        } else {
          this.setProperties({
            draftStatus: null,
            draftConflictUser: null,
            draftForceSave: false,
          });
        }

        return result;
      })
      .catch((e: AjaxError | null | undefined) => {
        let draftStatus;
        const xhr = e && e.jqXHR;

        if (
          xhr &&
          xhr.status === 409 &&
          xhr.responseJSON &&
          xhr.responseJSON.errors &&
          xhr.responseJSON.errors.length
        ) {
          const json = e!.jqXHR!.responseJSON!;
          draftStatus = json.errors![0];

          if (json.extras?.description) {
            this.dialog.alert({
              message: json.extras.description,
              buttons: [
                {
                  label: i18n("composer.reload"),
                  class: "btn-primary",
                  action: () => window.location.reload(),
                },
                {
                  label: i18n("composer.ignore"),
                  class: "btn-default",
                  action: () => this.set("draftForceSave", true),
                },
              ],
            });
          }
        }
        this.setProperties({
          draftStatus: draftStatus || i18n("composer.drafts_offline"),
          draftConflictUser: null,
        });
      })
      .finally(() => {
        this.set("draftSaving", false);
      });
  }

  customizationFor(type: string) {
    for (let i = 0; i < _customizations.length; i++) {
      // eslint-disable-next-line prefer-const
      let cb = _customizations[i][type];
      if (cb) {
        // eslint-disable-next-line prefer-const
        let result = cb(this);
        if (result) {
          return result;
        }
      }
    }
  }

  @on("init")
  _setupComposer() {
    this.set("archetypeId", this.site.default_archetype);
  }

  _open(opts: ComposerOpenOptions) {
    let promise: Promise<unknown> = Promise.resolve();

    this.set("loading", true);

    if (
      !isEmpty(this.reply) &&
      (opts.reply || isEdit(opts.action)) &&
      this.replyDirty
    ) {
      return promise;
    }

    if (opts.action === REPLY && isEdit(this.action)) {
      this.set("reply", "");
    }

    if (!opts.draftKey) {
      throw new Error("draft key is required");
    }

    if (opts.draftSequence === null) {
      throw new Error("draft sequence is required");
    }

    if (opts.usernames) {
      deprecated("`usernames` is deprecated, use `recipients` instead.", {
        id: "discourse.composer.usernames",
      });
    }

    this.setProperties({
      draftKey: opts.draftKey,
      draftSequence: opts.draftSequence,
      composeState: opts.composerState || OPEN,
      action: opts.action,
      topic: opts.topic,
      targetRecipients: opts.usernames || opts.recipients,
      composerTotalOpened: opts.composerTime,
      typingTime: opts.typingTime,
      whisper: opts.whisper,
      tags: opts.tags || [],
      noBump: opts.noBump,
      originalText: opts.originalText,
      originalTitle: opts.originalTitle,
      originalTags: opts.originalTags,
    });

    if (opts.post) {
      this.setProperties({
        post: opts.post,
        whisper:
          opts.whisper ?? opts.post.post_type === this.site.post_types!.whisper,
      });

      if (!this.topic) {
        if (opts.post.topic) {
          this.set("topic", opts.post.topic);
        } else {
          // handles the edge cases where the topic model is not loaded in the post model and the store does not have a
          // topic for the post, e.g., make a post then edit right away, edit a post outside the post stream, etc.
          promise = promise.then(async () => {
            const data = await Topic.find(opts.post!.topic_id!, {});
            const topic = this.store.createRecord("topic", data);
            this.post!.set("topic", topic);
            this.set("topic", topic);
          });
        }
      }
    } else if (opts.postId) {
      promise = promise.then(() =>
        this.store.find("post", opts.postId).then((post) => {
          this.set("post", post);
          if (post) {
            this.set("topic", post.topic);
          }
        })
      );
    } else {
      this.set("post", null);
    }

    this.setProperties({
      archetypeId: opts.archetypeId || this.site.default_archetype,
      metaData: opts.metaData ? EmberObject.create(opts.metaData) : null,
      adminOnboardingTopicOption: opts.adminOnboardingTopicOption ?? null,
      reply: opts.reply || this.reply || "",
    });

    // We set the category id separately for topic templates on opening of composer
    if (!opts.readOnlyCategoryId) {
      this.set(
        "categoryId",
        opts.topicCategoryId || opts.categoryId || this.get("topic.category.id")
      );
    }

    if (!this.categoryId && this.creatingTopic) {
      const categories = this.site.categories;
      if (categories.length === 1) {
        this.set("categoryId", categories[0].id);
      }
    }

    this._hasTopicTemplates = this.site.categories.some(
      (c) => c.topic_template
    );

    // If we are editing a post, load it.
    if (isEdit(opts.action) && this.post) {
      const topicProps = this.serialize(_edit_topic_serializer);
      topicProps.loading = true;
      topicProps.tags = this.topic!.tags;

      // When editing a shared draft, use its category
      if (opts.action === EDIT_SHARED_DRAFT && opts.destinationCategoryId) {
        topicProps.categoryId = opts.destinationCategoryId;
      }
      this.setProperties(topicProps);

      promise = promise.then(async () => {
        // Legacy postId loading does not populate opts.post; preserve that edit-path assumption.
        const post = await this.store.find("post", opts.post!.id);
        // When a draft is being restored, `opts` already carries the
        // composer's saved `reply_to_*` state (see `_draft_serializer`).
        // Prefer those values so pending reply-target changes survive a
        // reload or navigation; fall back to the post's stored state
        // otherwise. `undefined` means the key wasn't in the draft at all.
        //
        // `post.reply_to_user` is a rich `User` model instance with
        // circular back-refs (via `statusManager`), so we extract a plain
        // snapshot — otherwise `JSON.stringify` during periodic draft saves
        // throws "Converting circular structure to JSON".
        const replyToPostNumber =
          opts.reply_to_post_number !== undefined
            ? opts.reply_to_post_number
            : (post.reply_to_post_number ?? null);
        const postReplyToUser = post.reply_to_user;
        const replyToUser =
          opts.reply_to_user !== undefined
            ? opts.reply_to_user
            : postReplyToUser
              ? {
                  id: postReplyToUser.id,
                  username: postReplyToUser.username,
                  name: postReplyToUser.name,
                  avatar_template: postReplyToUser.avatar_template,
                }
              : null;
        this.setProperties({
          post,
          reply: post.raw,
          originalText: post.raw,
          originalTitle: this.topic!.title,
          reply_to_post_number: replyToPostNumber,
          reply_to_user: replyToUser,
        });

        if (post.post_number === 1 && this.canEditTitle) {
          this.setProperties({
            originalTags: this.topic!.tags,
          });
        }

        this.appEvents.trigger("composer:reply-reloaded", this);
      });
    } else if (opts.action === REPLY && opts.quote) {
      this.set("reply", opts.quote);
      this.set("originalText", opts.quote);
    }

    if (opts.title) {
      this.set("title", opts.title);
    }

    if (this.canEditTitle) {
      if (isEmpty(this.title) && this.title !== "") {
        this.set("title", "");
      }
    }

    if (!isEdit(opts.action) || !opts.post) {
      promise = promise.then(() =>
        this.appEvents.trigger("composer:reply-reloaded", this)
      );
    }

    // Ensure additional draft fields are set
    Object.keys(_add_draft_fields).forEach((f) => {
      this.set(_add_draft_fields[f], opts[f]);
    });

    return promise.finally(() => {
      this.set("loading", false);
    });
  }
}
