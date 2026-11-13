# Rendering and transformations

Use for XSS, HTML injection, tags, Markdown, oneboxes or content rewritten after validation.

## 1. Prove the input path

- [ ] Show how the actor supplies the value, including queued post metadata or
  remote response data. A crafted database value proves no external ingress.
- [ ] Record the value at validation and at final use: normalization → Markdown
  → sanitized HTML → restored fragments → attributes → cache or email output.
- [ ] Identify every rewrite after sanitization or validation. Test whether
  restoring raw HTML or removing a full quote can turn previously inert content
  into active markup or change content outside the intended rewrite.

## 2. Inspect the actual output

- [ ] Parse the generated output and inspect text, attributes and neighboring
  nodes. An escaped substring alone does not prove the boundary holds.
- [ ] Separate URL segment encoding from HTML attribute escaping. Check both
  where a tag slug becomes a link.
- [ ] Follow the real consumer: browser, composer preview, published post or email.
  Protection in one output does not establish protection in another.
- [ ] Compare fresh and cached results after policy changes. Verify whether
  onebox preview cache selection or invalidation respects the current hotlink policy.
- [ ] Identify output built after normal sanitization. Check whether warning
  favicons or other separately rendered output bypass the intended policy.

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
