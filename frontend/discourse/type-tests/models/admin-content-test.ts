import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import ColorScheme from "discourse/admin/models/color-scheme";
import ColorSchemeColor from "discourse/admin/models/color-scheme-color";
import EmailPreview, { oneWeekAgo } from "discourse/admin/models/email-preview";
import EmailSettings from "discourse/admin/models/email-settings";
import EmailStyle from "discourse/admin/models/email-style";
import EmailTemplate from "discourse/admin/models/email-template";
import Embedding from "discourse/admin/models/embedding";
import FlagType from "discourse/admin/models/flag-type";
import FormTemplate from "discourse/admin/models/form-template";
import Permalink from "discourse/admin/models/permalink";
import SiteText from "discourse/admin/models/site-text";
import UserField from "discourse/admin/models/user-field";
import type LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import type Category from "discourse/models/category";
import type RestModel from "discourse/models/rest";
import type {
  default as StoreService,
  ModelFor,
  ResultSetOf,
} from "discourse/services/store";

type FieldKind =
  | "text"
  | "textarea"
  | "date"
  | "confirm"
  | "dropdown"
  | "multiselect";
type TextStatus =
  | "up_to_date"
  | "outdated"
  | "invalid_interpolation_keys"
  | "deprecated";
type TemplateData = { id: number; name: string; template: string };
type PaletteData = {
  id: number;
  name: string;
  is_base: boolean | null;
  base_scheme_id: number | null;
  theme_id: number | null;
  theme_name: string | null;
  user_selectable: boolean;
  is_builtin_default: boolean | null;
  is_dark: boolean | null;
  colors: {
    name: string;
    hex: string;
    default_hex: string | null;
    is_advanced: boolean;
  }[];
};

declare const store: StoreService;

expectTypeOf<ModelFor<"site-text">>().toEqualTypeOf<SiteText>();
expectTypeOf<ModelFor<"email-style">>().toEqualTypeOf<EmailStyle>();
expectTypeOf<ModelFor<"email-template">>().toEqualTypeOf<EmailTemplate>();
expectTypeOf<ModelFor<"embedding">>().toEqualTypeOf<Embedding>();
expectTypeOf<ModelFor<"permalink">>().toEqualTypeOf<Permalink>();
expectTypeOf<ModelFor<"user-field">>().toEqualTypeOf<UserField>();
expectTypeOf(store.find("email-style")).resolves.toEqualTypeOf<EmailStyle>();
expectTypeOf(store.find("embedding")).resolves.toEqualTypeOf<Embedding>();
expectTypeOf(
  store.find("permalink", "112")
).resolves.toEqualTypeOf<Permalink>();
expectTypeOf(
  store.find("user-field", "252")
).resolves.toEqualTypeOf<UserField>();
expectTypeOf(store.findAll("email-template")).resolves.toEqualTypeOf<
  ResultSetOf<EmailTemplate> | undefined
>();
expectTypeOf(store.findAll("user-field")).resolves.toEqualTypeOf<
  ResultSetOf<UserField> | undefined
>();
store.find("site-text", {
  q: "title",
  locale: "en",
  overridden: true,
  page: 0,
});

declare const scheme: ColorScheme;
declare const schemes: Awaited<ReturnType<typeof ColorScheme.findAll>>;
declare const color: ColorSchemeColor;

expectTypeOf<Omit<ColorScheme, "destroy">>().toExtend<
  Omit<EmberObject, "destroy">
>();
expectTypeOf(scheme).not.toExtend<RestModel>();
expectTypeOf(schemes).toExtend<LegacyArrayLikeObject<ColorScheme>>();
expectTypeOf(schemes.content).toEqualTypeOf<ColorScheme[]>();
expectTypeOf(schemes.loading).toEqualTypeOf<boolean>();
ColorScheme.findAll();
schemes.loading = false;
schemes.content.push(scheme);
expectTypeOf(ColorScheme.find(860)).resolves.toEqualTypeOf<ColorScheme>();
ColorScheme.find("860");

ColorScheme.create({
  id: 860,
  name: "Captured palette",
  is_base: null,
  base_scheme_id: null,
  theme_id: null,
  theme_name: null,
  user_selectable: true,
  is_builtin_default: null,
  is_dark: false,
  colors: [
    { name: "primary", hex: "222", default_hex: "222", is_advanced: false },
  ],
});
// The manager constructs an id-only instance; copies omit server metadata.
ColorScheme.create({ id: 860 });
ColorScheme.create({ name: "Copy", can_edit: true, colors: [] });
expectTypeOf(scheme.id).toEqualTypeOf<number | undefined>();
expectTypeOf(scheme.name).toEqualTypeOf<string | undefined>();
expectTypeOf(scheme.user_selectable).toEqualTypeOf<boolean | undefined>();
expectTypeOf(scheme.is_base).toEqualTypeOf<boolean | null | undefined>();
expectTypeOf(scheme.is_builtin_default).toEqualTypeOf<
  boolean | null | undefined
>();
expectTypeOf(scheme.is_dark).toEqualTypeOf<boolean | null | undefined>();
expectTypeOf(scheme.theme_id).toEqualTypeOf<number | null | undefined>();
expectTypeOf(scheme.theme_name).toEqualTypeOf<string | null | undefined>();
expectTypeOf(scheme.base_scheme_id).toEqualTypeOf<number | null | undefined>();
expectTypeOf(scheme.can_edit).toEqualTypeOf<boolean | undefined>();
expectTypeOf(scheme.default_light_on_theme).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(scheme.default_dark_on_theme).toEqualTypeOf<boolean | undefined>();
expectTypeOf(scheme.saving).toEqualTypeOf<boolean | undefined>();
expectTypeOf(scheme.savingStatus).toEqualTypeOf<string | null | undefined>();
expectTypeOf(scheme.originals).toEqualTypeOf<{
  name: string | undefined;
  user_selectable: boolean | undefined;
}>();
expectTypeOf(scheme.colors).toEqualTypeOf<ColorSchemeColor[]>();
scheme.colors = [color];
scheme.name = "Renamed";
scheme.base_scheme_id = null;
scheme.default_light_on_theme = true;
scheme.default_dark_on_theme = false;
scheme.savingStatus = null;
expectTypeOf(scheme.newRecord).toEqualTypeOf<boolean>();
expectTypeOf(scheme.description).toEqualTypeOf<string>();
expectTypeOf(scheme.changed).toEqualTypeOf<boolean>();
expectTypeOf(scheme.disableSave).toEqualTypeOf<boolean>();
expectTypeOf(scheme.startTrackingChanges()).toEqualTypeOf<void>();
expectTypeOf(scheme.schemeJson()).toEqualTypeOf<string>();
expectTypeOf(scheme.schemeObject()).toEqualTypeOf<{
  name: string | undefined;
  light: Record<string, string | null | undefined>;
}>();
expectTypeOf(scheme.dump()).toEqualTypeOf<string>();
expectTypeOf(scheme.copy()).toEqualTypeOf<ColorScheme>();
expectTypeOf(scheme.save()).toEqualTypeOf<Promise<void> | undefined>();
scheme.save({ forceSave: true });
scheme.save({ saveNameOnly: true, forceSave: true });
scheme.save({ enabledOnly: true });
expectTypeOf(scheme.updateUserSelectable(true)).toEqualTypeOf<
  Promise<PaletteData> | undefined
>();
expectTypeOf(
  scheme.updateDefaultOnTheme("default_light_on_theme", true)
).toEqualTypeOf<Promise<PaletteData> | undefined>();
scheme.updateDefaultOnTheme("default_dark_on_theme", false);
expectTypeOf(scheme.destroy()).toEqualTypeOf<
  Promise<{ success: string }> | undefined
>();

expectTypeOf(color).toExtend<EmberObject>();
expectTypeOf(color).not.toExtend<RestModel>();
ColorSchemeColor.create({ name: "primary", hex: "222" });
ColorSchemeColor.create({
  name: "custom",
  hex: "abcdef",
  default_hex: null,
  is_advanced: true,
});
expectTypeOf(color.name).toEqualTypeOf<string>();
// Revert copies default_hex, which can be absent or null, into hex.
expectTypeOf(color.hex).toEqualTypeOf<string | null | undefined>();
expectTypeOf(color.originalHex).toEqualTypeOf<string | null | undefined>();
expectTypeOf(color.default_hex).toEqualTypeOf<string | null | undefined>();
expectTypeOf(color.is_advanced).toEqualTypeOf<boolean | undefined>();
expectTypeOf(color.originals).toEqualTypeOf<{ hex: string }>();
expectTypeOf(color.overridden).toEqualTypeOf<boolean>();
expectTypeOf(color.changed).toEqualTypeOf<boolean>();
expectTypeOf(color.savedIsOverriden).toEqualTypeOf<boolean>();
expectTypeOf(color.translatedName).toEqualTypeOf<string>();
expectTypeOf(color.description).toEqualTypeOf<string>();
expectTypeOf(color.brightness).toEqualTypeOf<number | undefined>();
expectTypeOf(color.valid).toEqualTypeOf<boolean>();
expectTypeOf(color.startTrackingChanges()).toEqualTypeOf<void>();
expectTypeOf(color.discardColorChange()).toEqualTypeOf<void>();
expectTypeOf(color.revert()).toEqualTypeOf<void>();
expectTypeOf(color.undo()).toEqualTypeOf<void>();
expectTypeOf(color.hexValueChanged()).toEqualTypeOf<void>();
color.hex = "abcdef";
color.default_hex = "222";

declare const siteText: SiteText;
expectTypeOf(siteText).toExtend<RestModel>();
store.createRecord("site-text", {
  id: "js.composer.reply",
  value: "Reply",
  status: "up_to_date",
  old_default: null,
  new_default: null,
  interpolation_keys: [],
  overridden: false,
  can_revert: false,
});
expectTypeOf(siteText.id).toEqualTypeOf<string>();
expectTypeOf(siteText.value).toEqualTypeOf<string>();
expectTypeOf(siteText.status).toEqualTypeOf<TextStatus>();
expectTypeOf(siteText.old_default).toEqualTypeOf<string | null>();
expectTypeOf(siteText.new_default).toEqualTypeOf<string | null>();
expectTypeOf(siteText.interpolation_keys).toEqualTypeOf<string[]>();
expectTypeOf(siteText.overridden).toEqualTypeOf<boolean>();
expectTypeOf(siteText.can_revert).toEqualTypeOf<boolean>();
expectTypeOf(siteText.revert("en")).resolves.toEqualTypeOf<
  Pick<
    SiteText,
    | "value"
    | "can_revert"
    | "overridden"
    | "status"
    | "old_default"
    | "new_default"
    | "interpolation_keys"
  >
>();
expectTypeOf(siteText.dismissOutdated("en")).resolves.toEqualTypeOf<{
  success: string;
}>();
siteText.save({ value: "Answer", locale: "en" });
siteText.status = "outdated";

declare const style: EmailStyle;
expectTypeOf(style).toExtend<RestModel>();
EmailStyle.create({ css: "body {}", default_css: "" });
EmailStyle.create({
  id: "email-style",
  html: "%{email_content}",
  css: "",
  default_html: "%{email_content}",
  default_css: "",
});
expectTypeOf(style.id).toEqualTypeOf<string | undefined>();
expectTypeOf(style.html).toEqualTypeOf<string | undefined>();
expectTypeOf(style.default_html).toEqualTypeOf<string | undefined>();
expectTypeOf(style.css).toEqualTypeOf<string>();
expectTypeOf(style.default_css).toEqualTypeOf<string>();
expectTypeOf(style.changed).toEqualTypeOf<boolean>();
expectTypeOf(style.setField("css", "body {}")).toEqualTypeOf<void>();
style.setField("html", "%{email_content}");
style.save({ html: "%{email_content}", css: "" });

declare const emailTemplate: EmailTemplate;
expectTypeOf(emailTemplate).toExtend<RestModel>();
EmailTemplate.create({
  id: "system_messages.user_posts_deleted",
  title: "User Posts Deleted",
  subject: "All posts deleted",
  body: { one: "%{count} post", other: "%{count} posts" },
  can_revert: false,
  interpolation_keys: ["user"],
});
EmailTemplate.create({ id: "invite_mailer", subject: null, body: "Hello" });
expectTypeOf(emailTemplate.id).toEqualTypeOf<string>();
expectTypeOf(emailTemplate.title).toEqualTypeOf<string>();
expectTypeOf(emailTemplate.subject).toEqualTypeOf<string | null>();
expectTypeOf(emailTemplate.body).toEqualTypeOf<
  string | Record<string, string>
>();
expectTypeOf(emailTemplate.can_revert).toEqualTypeOf<boolean>();
expectTypeOf(emailTemplate.interpolation_keys).toEqualTypeOf<string[]>();
expectTypeOf(emailTemplate.revert()).resolves.toEqualTypeOf<
  Pick<EmailTemplate, "subject" | "body" | "can_revert">
>();
emailTemplate.save({ subject: null, body: "Updated" });

declare const preview: EmailPreview;
expectTypeOf(preview).toExtend<EmberObject>();
expectTypeOf(preview).not.toExtend<RestModel>();
EmailPreview.create({ html_content: "<p>Hello</p>", text_content: "Hello" });
expectTypeOf(preview.html_content).toEqualTypeOf<string>();
expectTypeOf(preview.text_content).toEqualTypeOf<string>();
expectTypeOf(oneWeekAgo()).toEqualTypeOf<string>();
expectTypeOf(
  EmailPreview.findDigest("anne")
).resolves.toEqualTypeOf<EmailPreview>();
EmailPreview.findDigest("anne", null);
EmailPreview.findDigest("anne", "2026-10-20");
expectTypeOf(
  EmailPreview.sendDigest("anne", "2026-10-20", "anne@example.com")
).resolves.toExtend<{ success?: string; errors?: string | string[] | null }>();
expectTypeOf(
  EmailPreview.sendDigest("anne", null, "anne@example.com")
).resolves.not.toBeAny();
EmailPreview.sendDigest(null, null, null);
EmailPreview.sendDigest(undefined, null, "anne@example.com");

declare const emailSettings: EmailSettings;
expectTypeOf(emailSettings).toExtend<EmberObject>();
expectTypeOf(emailSettings).not.toExtend<RestModel>();
expectTypeOf(EmailSettings.find()).resolves.toEqualTypeOf<EmailSettings>();
EmailSettings.create({ delivery_method: "test", settings: [] });
expectTypeOf(emailSettings.delivery_method).toEqualTypeOf<string>();
// Mail transports supply their own settings values; the capture has no rows.
expectTypeOf(emailSettings.settings).toEqualTypeOf<
  { name: string; value: unknown }[]
>();

declare const embedding: Embedding;
expectTypeOf(embedding).toExtend<RestModel>();
Embedding.create({
  id: "default",
  fields: ["embed_by_username", "embed_post_limit"],
  base_url: "http://test.localhost",
  embed_by_username: "",
  embed_post_limit: 100,
  embed_title_scrubber: "",
  embed_truncate: true,
  embed_unlisted: false,
  allowed_embed_selectors: "",
  blocked_embed_selectors: "",
  allowed_embed_classnames: "emoji",
  embeddable_host_ids: [51],
});
expectTypeOf(embedding.id).toEqualTypeOf<string>();
expectTypeOf(embedding.fields).toEqualTypeOf<string[]>();
expectTypeOf(embedding.base_url).toEqualTypeOf<string>();
expectTypeOf(embedding.embed_by_username).toEqualTypeOf<string>();
expectTypeOf(embedding.embed_post_limit).toEqualTypeOf<number>();
expectTypeOf(embedding.embed_title_scrubber).toEqualTypeOf<string>();
expectTypeOf(embedding.embed_truncate).toEqualTypeOf<boolean>();
expectTypeOf(embedding.embed_unlisted).toEqualTypeOf<boolean>();
expectTypeOf(embedding.allowed_embed_selectors).toEqualTypeOf<string>();
expectTypeOf(embedding.blocked_embed_selectors).toEqualTypeOf<string>();
expectTypeOf(embedding.allowed_embed_classnames).toEqualTypeOf<string>();
expectTypeOf(embedding.embeddable_host_ids).toEqualTypeOf<
  number[] | undefined
>();
expectTypeOf(embedding.embeddable_hosts).not.toBeAny();
expectTypeOf(embedding.embeddable_hosts[0]).toExtend<RestModel>();
expectTypeOf(embedding.embeddable_hosts[0].id).toEqualTypeOf<number>();
expectTypeOf(embedding.embeddable_hosts[0].host).toEqualTypeOf<string>();
expectTypeOf(embedding.embeddable_hosts[0].allowed_paths).toEqualTypeOf<
  string | null
>();
expectTypeOf(embedding.embeddable_hosts[0].class_name).toEqualTypeOf<
  string | null
>();
expectTypeOf(embedding.embeddable_hosts[0].category_id).toEqualTypeOf<number>();
expectTypeOf(embedding.embeddable_hosts[0].user).toEqualTypeOf<string | null>();
expectTypeOf(embedding.embeddable_hosts[0].tags).toEqualTypeOf<
  { id: number; name: string; slug: string }[]
>();
embedding.embeddable_hosts = [];
embedding.embeddable_hosts.push(embedding.embeddable_hosts[0]);
embedding.embeddable_hosts[0].save({
  host: "example.com",
  tags: [1],
  user: "anne",
});
embedding.update({
  type: "posts_and_topics",
  embed_by_username: "anne",
  embed_post_limit: 100,
  embed_title_scrubber: "",
  embed_truncate: true,
  embed_unlisted: false,
});
embedding.update({
  type: "crawlers",
  allowed_embed_selectors: "article",
  blocked_embed_selectors: "nav",
  allowed_embed_classnames: "emoji",
});

declare const permalink: Permalink;
expectTypeOf(permalink).toExtend<RestModel>();
Permalink.create({
  id: 113,
  url: "ext",
  topic_id: null,
  topic_title: null,
  topic_url: null,
  post_id: null,
  post_url: null,
  post_number: null,
  post_topic_title: null,
  category_id: null,
  category_name: null,
  category_url: null,
  external_url: "https://example.com",
  tag_id: null,
  tag_name: null,
  tag_url: null,
  user_id: null,
  user_url: null,
  username: null,
});
expectTypeOf(permalink.id).toEqualTypeOf<number | undefined>();
expectTypeOf(permalink.url).toEqualTypeOf<string>();
expectTypeOf(permalink.topic_id).toEqualTypeOf<number | null>();
expectTypeOf(permalink.post_id).toEqualTypeOf<number | null>();
expectTypeOf(permalink.category_id).toEqualTypeOf<number | null>();
expectTypeOf(permalink.tag_id).toEqualTypeOf<number | null>();
expectTypeOf(permalink.user_id).toEqualTypeOf<number | null>();
expectTypeOf(permalink.post_number).toEqualTypeOf<number | null>();
expectTypeOf(permalink.topic_title).toEqualTypeOf<string | null>();
expectTypeOf(permalink.topic_url).toEqualTypeOf<string | null>();
expectTypeOf(permalink.post_url).toEqualTypeOf<string | null>();
expectTypeOf(permalink.post_topic_title).toEqualTypeOf<string | null>();
expectTypeOf(permalink.category_name).toEqualTypeOf<string | null>();
expectTypeOf(permalink.category_url).toEqualTypeOf<string | null>();
expectTypeOf(permalink.external_url).toEqualTypeOf<string | null>();
expectTypeOf(permalink.tag_name).toEqualTypeOf<string | null>();
expectTypeOf(permalink.tag_url).toEqualTypeOf<string | null>();
expectTypeOf(permalink.user_url).toEqualTypeOf<string | null>();
expectTypeOf(permalink.username).toEqualTypeOf<string | null>();
expectTypeOf(permalink.category).toEqualTypeOf<Category | undefined>();
expectTypeOf(permalink.linkIsExternal).toEqualTypeOf<boolean>();
expectTypeOf(permalink.key).toEqualTypeOf<string>();
expectTypeOf(Permalink.findAll()).resolves.toEqualTypeOf<Permalink[]>();
Permalink.findAll(null);
Permalink.findAll("old/path");
store.createRecord("permalink").save({
  url: "old/path",
  permalink_type: "topic",
  permalink_type_value: "22928",
});
store.createRecord("permalink").save({
  url: "ext",
  permalink_type: "external_url",
  permalink_type_value: "https://example.com",
});

declare const template: FormTemplate;
expectTypeOf(template).toExtend<RestModel>();
FormTemplate.create({ id: 84, name: "Bug report", template: "- type: input" });
expectTypeOf(template.id).toEqualTypeOf<number>();
expectTypeOf(template.name).toEqualTypeOf<string>();
expectTypeOf(template.template).toEqualTypeOf<string>();
expectTypeOf(FormTemplate.findAll()).resolves.toEqualTypeOf<TemplateData[]>();
expectTypeOf(
  FormTemplate.findById("84")
).resolves.toEqualTypeOf<TemplateData>();
FormTemplate.findById(84);
expectTypeOf(FormTemplate.findById(84)).resolves.not.toExtend<RestModel>();
expectTypeOf(
  FormTemplate.createTemplate({ name: "Bug report", template: "- type: input" })
).resolves.toEqualTypeOf<{ form_template: TemplateData }>();
expectTypeOf(
  FormTemplate.updateTemplate(84, {
    name: "Bug report",
    template: "- type: input",
  })
).resolves.toEqualTypeOf<{ form_template: TemplateData }>();
FormTemplate.updateTemplate("84", {
  name: "Bug report",
  template: "- type: input",
});
expectTypeOf(
  FormTemplate.createOrUpdateTemplate({
    name: "Bug report",
    template: "- type: input",
  })
).resolves.toEqualTypeOf<{ form_template: TemplateData }>();
FormTemplate.createOrUpdateTemplate({
  id: 84,
  name: "Bug report",
  template: "- type: input",
});
expectTypeOf(
  FormTemplate.validateTemplate({
    id: 84,
    name: "Bug report",
    template: "- type: input",
  })
).resolves.toEqualTypeOf<{
  form_template: { id: number | null; name: string; template: string };
}>();
FormTemplate.validateTemplate({
  name: "Bug report",
  template: "- type: input",
});
expectTypeOf(FormTemplate.deleteTemplate(84)).resolves.toEqualTypeOf<{
  success: string;
}>();
FormTemplate.deleteTemplate("84");
// @ts-expect-error Preview requires YAML text, not a parsed array.
FormTemplate.validateTemplate({ name: "Bug report", template: [] });

declare const flagType: FlagType;
expectTypeOf(flagType).toExtend<RestModel>();
// No active loader supplies a narrower id contract for this legacy model.
expectTypeOf(flagType.id).toEqualTypeOf<number | string | undefined>();
expectTypeOf(flagType.name).toEqualTypeOf<string>();
FlagType.create({ id: 3 });

declare const userField: UserField;
declare const fieldType: ReturnType<typeof UserField.fieldTypes>[number];
expectTypeOf(userField).toExtend<RestModel>();
store.createRecord("user-field", {
  field_type: "text",
  requirement: "optional",
  show_on_signup: true,
});
UserField.create({
  id: 252,
  name: "Favourite colour",
  description: "user field description",
  field_type: "dropdown",
  editable: true,
  required: true,
  requirement: "on_signup",
  show_on_profile: false,
  show_on_user_card: false,
  show_on_signup: true,
  searchable: false,
  position: 0,
  options: ["Red"],
});
expectTypeOf(userField.id).toEqualTypeOf<number | undefined>();
expectTypeOf(userField.name).toEqualTypeOf<string | undefined>();
expectTypeOf(userField.description).toEqualTypeOf<string | undefined>();
expectTypeOf(userField.field_type).toEqualTypeOf<FieldKind>();
expectTypeOf(userField.requirement).toEqualTypeOf<
  "optional" | "for_all_users" | "on_signup"
>();
expectTypeOf(userField.editable).toEqualTypeOf<boolean | undefined>();
expectTypeOf(userField.required).toEqualTypeOf<boolean | undefined>();
expectTypeOf(userField.show_on_profile).toEqualTypeOf<boolean | undefined>();
expectTypeOf(userField.show_on_user_card).toEqualTypeOf<boolean | undefined>();
expectTypeOf(userField.show_on_signup).toEqualTypeOf<boolean>();
expectTypeOf(userField.searchable).toEqualTypeOf<boolean | undefined>();
expectTypeOf(userField.position).toEqualTypeOf<number | null | undefined>();
expectTypeOf(userField.options).toEqualTypeOf<string[] | undefined>();
expectTypeOf(userField.fieldTypeName).toEqualTypeOf<string>();
expectTypeOf(fieldType).toExtend<EmberObject>();
expectTypeOf(fieldType).not.toExtend<RestModel>();
expectTypeOf(fieldType.id).toEqualTypeOf<FieldKind>();
expectTypeOf(fieldType.name).toEqualTypeOf<string>();
expectTypeOf(fieldType.hasOptions).toEqualTypeOf<boolean | undefined>();
expectTypeOf(UserField.fieldTypes()).toEqualTypeOf<(typeof fieldType)[]>();
expectTypeOf(UserField.fieldTypeById("dropdown")).toEqualTypeOf<
  typeof fieldType | undefined
>();
UserField.fieldTypeById("unknown");
UserField.fieldTypeById(undefined);
userField.field_type = "multiselect";
userField.requirement = "for_all_users";
userField.options = ["Red", "Blue"];
userField.save({ field_type: "dropdown", options: ["Red"], editable: true });
// @ts-expect-error The serializer sends option labels, not numeric ids.
userField.options = [1];
