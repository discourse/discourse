# Rendering and transformations

Use for XSS, HTML injection, tags, Markdown, oneboxes or rewritten content.

## 1. Prove the input path

- [ ] Establish actor control, including queued metadata and remote responses.
  Crafted database values do not prove ingress.
- [ ] Track validation to final use: normalization → Markdown → sanitization
  → restored fragments → attributes → caches or email.
- [ ] Inspect every later rewrite. Can restored raw HTML or quote removal activate
  inert content or change content outside the intended rewrite?

## 2. Inspect output

- [ ] Parse actual text, attributes and neighboring nodes. Escaped substrings alone
  do not prove safe output.
- [ ] Check URL segment encoding and HTML attribute escaping separately when
  tag slugs become links.
- [ ] Follow each consumer: browser, preview, published post and email.
  Protection in one does not establish protection in another.
- [ ] Compare fresh and cached output after policy changes. Check onebox cache
  selection and invalidation against current hotlink policy.
- [ ] Check output built outside normal sanitization, including warning favicons,
  against the intended policy.

## 3. Check defenses and effect

- [ ] Verify CSP enforcement in the actual configuration.
- [ ] Distinguish markup injection, script execution and account or server compromise.
  Prove each boundary.
- [ ] Record supported nondefault settings, including disabled CSP. Optional
  defenses reduce exposure without making an unsafe renderer correct.
- [ ] Use [Network and storage](network-storage.md) for browser media versus server
  fetches, or [Resource exhaustion](resource-limits.md) for expensive parsing.

## Decision gate

- **Unsafe sink only:** record missing ingress or effect. The exploit is unproven.
- **CSP blocks execution:** credit that configuration's control. Assess independent
  HTML injection, disclosure and supported alternate settings.
- **Independent harm:** retain it even if a later RCE step fails.
