import getURL from "discourse-common/lib/get-url";

export const ADMIN_NAV_MAP = [
  {
    name: "plugins",
    label: "admin.plugins.title",
    links: [
      {
        name: "admin_installed_plugins",
        route: "adminPlugins.index",
        label: "admin.plugins.installed",
        icon: "puzzle-piece",
      },
    ],
  },
  {
    name: "email",
    text: "Emails",
    links: [
      {
        name: "admin_email",
        route: "adminEmail.index",
        label: "admin.email.settings",
        icon: "cog",
      },
      {
        name: "admin_email_sent",
        route: "adminEmail.sent",
        label: "admin.email.sent",
        icon: "arrow-right",
      },
      {
        name: "admin_email_skipped",
        route: "adminEmail.skipped",
        label: "admin.email.skipped",
        icon: "angle-double-right",
      },
      {
        name: "admin_email_bounced",
        route: "adminEmail.bounced",
        label: "admin.email.bounced",
        icon: "times",
      },
      {
        name: "admin_email_received",
        route: "adminEmail.received",
        label: "admin.email.received",
        icon: "inbox",
      },
      {
        name: "admin_email_rejected",
        route: "adminEmail.rejected",
        label: "admin.email.rejected",
        icon: "ban",
      },
      {
        name: "admin_email_preview_summary",
        route: "adminEmail.previewDigest",
        label: "admin.email.preview_digest",
        icon: "notification.private_message",
      },
      {
        name: "admin_email_advanced_test",
        route: "adminEmail.advancedTest",
        label: "admin.email.advanced_test.title",
        icon: "wrench",
      },
    ],
  },
  {
    name: "logs",
    label: "admin.logs.title",
    links: [
      {
        name: "admin_logs_staff_action_logs",
        route: "adminLogs.staffActionLogs",
        label: "admin.logs.staff_actions.title",
        icon: "user-shield",
      },
      {
        name: "admin_logs_screened_emails",
        route: "adminLogs.screenedEmails",
        label: "admin.logs.screened_emails.title",
        icon: "envelope",
      },
      {
        name: "admin_logs_screened_ip_addresses",
        route: "adminLogs.screenedIpAddresses",
        label: "admin.logs.screened_ips.title",
        icon: "globe",
      },
      {
        name: "admin_logs_screened_urls",
        route: "adminLogs.screenedUrls",
        label: "admin.logs.screened_urls.title",
        icon: "globe",
      },
      {
        name: "admin_logs_search_logs",
        route: "adminSearchLogs",
        label: "admin.logs.search_logs.title",
        icon: "search",
      },
      {
        name: "admin_logs_error_logs",
        href: getURL("/logs"),
        label: "admin.logs.logster.title",
        icon: "external-link-alt",
      },
    ],
  },
  {
    name: "customize",
    label: "admin.customize.title",
    links: [
      {
        name: "admin_customize_themes",
        route: "adminCustomizeThemes",
        label: "admin.customize.theme.title",
        icon: "paint-brush",
      },
      {
        name: "admin_customize_colors",
        route: "adminCustomize.colors",
        label: "admin.customize.colors.title",
        icon: "palette",
      },
      {
        name: "admin_customize_site_texts",
        route: "adminSiteText",
        label: "admin.site_text.title",
        icon: "language",
      },
      {
        name: "admin_customize_email_templates",
        route: "adminCustomizeEmailTemplates",
        label: "admin.email.templates_title",
        icon: "envelope",
      },
      {
        name: "admin_customize_email_style",
        route: "adminCustomizeEmailStyle",
        label: "admin.customize.email_style.title",
        icon: "envelope",
      },
      {
        name: "admin_customize_user_fields",
        route: "adminUserFields",
        label: "admin.user_fields.title",
        icon: "user-edit",
      },
      {
        name: "admin_customize_emojis",
        route: "adminEmojis",
        label: "admin.emoji.title",
        icon: "discourse-emojis",
      },
      {
        name: "admin_customize_permalinks",
        route: "adminPermalinks",
        label: "admin.permalink.title",
        icon: "link",
      },
      {
        name: "admin_customize_embedding",
        route: "adminEmbedding",
        label: "admin.embedding.title",
        icon: "code",
      },
      {
        name: "admin_customize_watched_words",
        route: "adminWatchedWords",
        label: "admin.watched_words.title",
        icon: "eye",
      },
    ],
  },
  {
    name: "api",
    label: "admin.api.title",
    links: [
      {
        name: "admin_api_keys",
        route: "adminApiKeys",
        icon: "key",
        label: "admin.api.keys",
      },
      {
        name: "admin_api_web_hooks",
        route: "adminWebHooks",
        label: "admin.web_hooks.title",
        icon: "globe",
      },
    ],
  },
  {
    name: "backups",
    label: "admin.backups.menu.backups",
    links: [
      {
        name: "admin_backups",
        route: "admin.backups.index",
        label: "admin.backups.menu.backups",
        icon: "archive",
      },
      {
        name: "admin_backups_logs",
        route: "admin.backups.logs",
        label: "admin.backups.menu.logs",
        icon: "stream",
      },
    ],
  },
];
