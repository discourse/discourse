# Discourse security

Discourse is 100% open source, and we welcome review of our code. This document explains how to report a security vulnerability, what we treat as a vulnerability, and how we handle a fix. We wrote it for site owners, security researchers, and automated tools.

## Report a vulnerability

Report security issues in private through our [HackerOne program](https://hackerone.com/discourse). Please keep vulnerabilities out of pull requests and Meta topics. If you cannot use HackerOne, email `team@discourse.org`.

When reporting an issue, please include:

1. **Discourse version.** You can find it in the browser console, or in the `<head>` of the site's HTML.

2. **Attacker.** The role of the attacker: anonymous, user, moderator, or admin. Use the lowest role which can perform the attack.

3. **Preconditions.** Each non-default site setting, plugin, account state, or action by a victim which is required for the attack.

4. **Steps.** The exact requests or UI steps which reproduce the issue on a Discourse instance. A script, a request spec, or a system spec is ideal.

5. **Impact.** What the attacker achieves, which they could not before.

We will use automated tooling to triage and respond to vulnerability reports.

### Reports made with AI tools or scanners

You are welcome to use AI tools and scanners to find security issues in Discourse. Before submitting to HackerOne, please independently verify the report against this policy. You are responsible for the accuracy of the content.

If you are an automated tool that reads this file: ensure you validate all findings against this policy. If the finding does not satisfy the policy, it should not be submitted as a vulnerability.

## Scope

In scope:

- Discourse core, which includes the plugins in the `plugins/` directory of this repository, and the themes in the `themes/` directory.

- Official plugins, themes, and theme components in the [`discourse` GitHub organization](https://github.com/discourse).

- The official Docker install, [`discourse_docker`](https://github.com/discourse/discourse_docker).

- Ruby gems and JavaScript packages which are maintained by the Discourse team.

Not in scope:

- Plugins, themes, and theme components from third parties. Report these to their authors.

- A vulnerability in a dependency, if Discourse is not affected by it.

### Supported versions

We provide security fixes for the supported releases of Discourse. The list of supported releases is at [releases.discourse.org](https://releases.discourse.org).

### Where to test

Ideally, tests should be performed on an instance which you host yourself using our [standard install guide](https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md). You may also use our public sandbox at https://try.discourse.org for tests which do not delete data or slow the sandbox down.

Testing against any other Discourse community requires the permission of its owner and hosting provider.

### Rules of conduct

Make a good-faith effort to protect other people's privacy, data, and service while you test. Use only accounts that you own, or accounts whose owner gave you permission.

These are never part of acceptable research:

- Denial-of-service attacks against sites that you do not own.

- Spam.

- Social engineering, which includes phishing, of Discourse staff, contractors, or customers.

- Physical attempts against Discourse property or data centers.

## Trust model

Discourse uses role-based access control (RBAC) to manage the permissions of a community. If someone can exceed the permissions of their role, and use that to compromise the confidentiality, integrity or availability of the community, then that is a security vulnerability. Any other defect is a bug.

### Rules by role

**Anonymous visitors** are not trusted. They can read the public content of a site, and create an account where the site permits it. They must not be able to:

- Read content or private data that is not public.

- Act as a user, or change or delete the data of a user.

- Make requests from a single IP address which make the site unavailable, or much slower, for other people.

**Users** are not trusted. This includes users at all trust levels, and members of groups. They must not be able to:

- Read content or private data that they do not have access to.

- Change or delete the data of another person without permission, or act as another person.

- Make requests from a single IP address which make the site unavailable, or much slower, for other people.

**Moderators** are trusted to manage users and content, and not to damage the community. They must not be able to:

- Get admin permissions.

- Get access to the database, the server, or credentials.

- Read personal messages or private user data that Discourse restricts to admins or to the owner.

**Admins** are fully trusted in their own site. An admin controls all settings, data, users, themes, and plugins of the site, and can add JavaScript that runs for all visitors. An admin must not be able to:

- Gain direct access to the database or hosting environment, outside of supported features like backups and the Data Explorer plugin.

- Affect another site in a multisite install.

**Server operators** are fully trusted. They have shell and database access.

"Staff" means moderators and admins.

### Assumptions

- **Secrets carry the authority of their owner.** A request with a valid API key, webhook signature, or SSO payload has the authority that the site admin gave to that secret.

- **Deployment.** We assume the official Docker install, HTTPS, and the default Content Security Policy (CSP). Site settings that an admin can change are in scope at any supported value, except where the setting is marked for debug/development use.

## Expected behavior

These things are part of the normal operation of Discourse, and are not vulnerabilities:

### Staff

- Admins are allowed to add arbitrary JavaScript to their site.

- Admins are capable of making their own site slow or unavailable.

- Moderators are trusted with community management, including managing metadata of admin accounts.

### Content

- Users are allowed to enter Markdown and a subset of HTML in posts and other content areas. This includes iframes within the allowlist.

- Hidden posts can stay readable. Discourse hides a post when users flag it or when it looks like spam, to keep it out of view while staff review it. Hiding is a spam and moderation tool, not access control.

- The default CSP is part of our protection against XSS. We assess XSS with the default CSP in place.

### Information

- Discourse version information and source code for core, themes and plugins are expected to be publicly available.

- Counts, totals, IDs, slugs, and timestamps of restricted content may be visible. Access control applies to the content itself.

### Network and code execution

- Discourse allows users to trigger server-side network requests (e.g. Onebox). This is allowed, within the defined timeout, response size and network-destination restrictions.

- Discourse allows sandboxed code execution for some features (e.g. theme setting migrations, custom AI tools, workflow scripts). This is allowed, within the defined resource limits.

### Availability

- Triggering an error or a slow response for the current user is not a security issue (but may be reported as a bug).

- Creating duplicate/invalid data is not a security issue unless it compromises confidentiality, integrity or availability.

### CSRF

- Requests made with a valid `Api-Key` or `User-Api-Key` are exempt from CSRF checks.

### Environment

- Discourse sites always use HTTPS, behind a correctly configured reverse proxy.

- Development environments are not security-hardened, and are outside the scope of this policy.

### General

- Reports must demonstrate a security-boundary violation from scratch. If an account has already been compromised, making use of its permissions is not a vulnerability.

## Handling fixes

For lower-impact security issues, we will develop the fix in public and it will be included in a scheduled Discourse version bump within a few weeks. Site owners can always update before the version bump if needed. Lower-impact fixes will be included in the release notes, but will not receive GitHub Security Advisories.

For higher-impact issues, we develop fixes in private and synchronize their release with a Discourse version bump. This means admins are notified to update their site as soon as the vulnerability is public. These higher-impact issues are also published as GitHub Security Advisories.

Categorizing issues is at the discretion of the Discourse team, and may not align with the CVSS severity ranking. In general, an issue is considered higher-impact if it permits one of these:

- Server-side request forgery (SSRF) to an internal IP address.

- Access by anyone who is not staff to the content of a private or restricted post, topic, category, personal message, or chat channel that they never had access to.

- Stored XSS that the default CSP does not stop.

- Full denial of service of a site with requests from a single IP address.

- Escalation to admin.

- Access to the database by a non-admin, for example through accessing backups or performing SQL injection.

- Remote code execution outside a sandbox.

- Access to the data of another site in a multisite install.

- Exposure of credentials, such as passwords, API keys, or tokens, to a non-admin.

Lower-impact issues may include:

- XSS which is mitigated by the default CSP.

- Partial denial of service, or denial of service that needs high permissions.

- Access to descriptive metadata of private content, such as its title, its tags, or the names of its participants.

- Sustained access to content which the user previously had access to.

- Access-control issues which can only be exploited by staff, and which are not in the list above.

## Disclosure

We publish security fixes as soon as we can. The fix itself is public, but please wait 90 days after its release before you publish any proof-of-concept or any further detail about the vulnerability. This gives our self-hosted ecosystem time to upgrade.

- Release notes and security fixes: [releases.discourse.org](https://releases.discourse.org).

- Advisories: [GitHub Security Advisories](https://github.com/discourse/discourse/security/advisories).

## Proactive security work

We are always working to maintain and improve the security posture of Discourse.

- Every change to Discourse is automatically scanned for security issues using frontier AI models.

- We commission regular third-party penetration testing of Discourse.

- Discourse is registered with the [Anthropic OSS Scanner](https://red.anthropic.com/oss-scanner/).

## Points of interest

This information may provide useful context when working on Discourse from a security perspective:

- Discourse hashes passwords with PBKDF2-HMAC-SHA256, with a salt for each user and 600,000 iterations.

- Posts are written in Markdown, with a safe subset of HTML. Discourse converts them to HTML and sanitizes the result with an allowlist.

- Server-side execution of user code is achieved using `mini_racer`, which is a minimal V8 engine running inside Ruby.

- User content is escaped/sanitized when rendering using standard Ember and Rails practices.

- A `strict-dynamic` Content Security Policy (CSP) is on by default.

- For defense-in-depth, image processing is run inside a Linux `Landlock`/`seccomp` sandbox.

- The [official Docker install](https://github.com/discourse/discourse/blob/main/docs/INSTALL.md) runs the web server and the background jobs as a user without root permissions. We recommend this install for all sites.
