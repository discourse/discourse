---
title: Translatable email headers and footers
short_title: Email branding
id: email-branding
---

Email branding is an opt-in feature for sites with a custom default theme. Enable the hidden `enable_email_theme_header_and_footer` site setting to include the default theme's email fields in outgoing messages. Attached theme components do not contribute email branding. Built-in themes do not expose editable email fields.

## Theme files

Git themes can supply these files:

- `email/header.html`
- `email/footer.html`
- `email/header.txt` (optional)
- `email/footer.txt` (optional)

For a local custom theme, edit the equivalent fields in the theme editor's **Email** tab. For Git themes, edit the files in the repository and update the theme. Changing the site's default theme changes the branding used by subsequent emails.

The HTML files are trusted email markup. Use email-compatible HTML, absolute image URLs, and inline styles; frontend theme JavaScript and stylesheets are not included. Translation substitutions are plain text and are HTML-escaped; keep markup in the HTML files rather than in translations.

For example, `email/footer.html`:

```html
<footer>
  <p>%{email_branding.notice}</p>
  <a href="%{unsubscribe_url}">%{email_branding.preferences}</a>
</footer>
```

Translations are defined in the theme's locale files, such as `locales/en.yml`:

```yaml
en:
  email_branding:
    notice: "You are receiving this email because you participate in our community."
    preferences: "Update your notification preferences"
```

`%{unsubscribe_url}` resolves to the message's unsubscribe URL when available, otherwise to the site's preferences page. Missing translation keys remain visible as placeholders. Both email formats use the locale selected by the mailer, with the normal theme translation fallbacks.

If a `.txt` file is absent, its plain-text fragment is derived from the corresponding HTML file. Semantic containers retain their contents and relative links are resolved before conversion. For complex table layouts, use the optional text files to control the result. Text files support the same substitutions without HTML escaping or conversion. The original message text is preserved, including literal HTML entities.

## Global email template

The global Email Style HTML template supports `%{theme_email_header}` and `%{theme_email_footer}` slots. Templates with neither slot have the fragments inserted around `%{email_content}` for compatibility. A template that includes either slot controls which HTML fragments appear; the text files independently control the plain-text version.

## Previewing before rollout

Visit `/admin/email/preview` and choose a custom branding theme to preview a draft without changing the site's default theme or enabling live branding. Existing `/admin/email/preview-digest` links redirect to this page, preserving their query parameters. Selections can be shared through the URL parameters `username`, `email_type`, `locale`, `last_seen_at`, and `theme_id`.

Without an explicit language, the preview uses the selected user's effective locale. After changing selections, refresh before sending a test message. Preview sends respect `disable_emails`; the dedicated SMTP test retains its existing delivery behavior. `restrict_admin_email_test_sends_to_self` optionally restricts test recipients to addresses associated with the current administrator. Both send endpoints are rate-limited.

Credential previews contain deliberately invalid tokens or codes. Use **Preview saved template** in an Email Templates editor to inspect a literal template without filling the general message selector with templates. Literal template previews leave runtime placeholders unresolved; they are not a substitute for testing the actual application workflow.
