# Rendering and transformations

Use for XSS, HTML injection, tags, Markdown, oneboxes or content rewritten after validation.

## 1. Prove the input path

- [ ] Show how the actor supplies the value, including queued post metadata or
  remote response data. A crafted database value proves no external ingress.
- [ ] Record the value at validation and at final use: normalization → Markdown
  → sanitized HTML → restored fragments → attributes → cache or email output.
- [ ] Identify every rewrite after sanitization or validation.
  **Observed defenses:** [cooking fixes](https://github.com/discourse/discourse/commit/844df56adea6c72f740c5dbaf79b076d7390b210) constrain restored raw HTML and the
  [full quote removal guard](https://github.com/discourse/discourse/commit/6086e452c0dfd5857adecbbb9f2e0fd5232e30c7) rejects rewrites that change the remaining content.

## 2. Inspect the actual output

- [ ] Parse the generated output and inspect text, attributes and neighboring
  nodes. An escaped substring alone does not prove the boundary holds.
- [ ] Separate URL segment encoding from HTML attribute escaping. Check both
  where a tag slug becomes a link.
- [ ] Follow the real consumer: browser, composer preview, published post or email.
  Protection in one output does not establish protection in another.
- [ ] Compare fresh and cached results after policy changes.
  **Observed defense:** [Onebox preview caches](https://github.com/discourse/discourse/commit/1f1e241c584ede2358e20d1e616b58a2c11cf785) include the hotlink policy.
- [ ] Check output built after normal sanitization. Warning favicons need their
  own policy check because the normal onebox sanitizer never sees them.

## 3. Check downstream defenses and effect

- [ ] Observe whether CSP prevents execution in the actual configuration.
- [ ] Separate injected markup, script execution and any claimed account or server
  compromise. Prove each additional boundary rather than assuming a chain.
- [ ] Record supported nondefault settings exercised, including disabled CSP.
  An optional defense can reduce exposure without making an unsafe renderer correct.
- [ ] For browser media loads versus server fetches, continue with
  [Network, storage and isolation](network-storage.md).
- [ ] If the claim is expensive parsing rather than injection, use
  [Resource exhaustion](resource-limits.md).

## Decision gate

- **Unsafe sink only:** record the mechanism and missing ingress or effect.
  Do not claim the entire exploit is demonstrated.
- **CSP blocks execution:** credit the observed control for this configuration.
  Assess independent HTML injection or disclosure and any supported alternate setting.
- **Independent harm demonstrated:** retain that result even if a later RCE link fails.
