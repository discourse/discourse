# Network, storage and isolation

Use for SSRF, remote media, upload races, filesystem access, archives, native decoders or multisite.

## 1. Establish where the operation runs

- [ ] Distinguish browser image requests from server fetches. Identify the network
  client and effective SSRF controls on each server path, including any use of
  FinalDestination. Browser access does not prove server access to that address.
- [ ] Record the actual server destination and returned data or side effect.
- [ ] For server requests, follow DNS resolution, allowed internal hosts, ports and
  every redirect. Test whether host exceptions also permit unintended ports,
  including through onebox redirects.
- [ ] Check fresh, cached and warning card output when the claim concerns remote
  media policy. Use [Rendering and transformations](rendering.md) for those paths.

## 2. Follow validated bytes and file paths

- [ ] Compare bytes validated with bytes ultimately stored or consumed. Can the
  actor replace the remote object between those operations?
  Follow direct S3 completion through validation, hashing, storage and deduplication.
- [ ] Check filesystem containment after normalization, archive entry types and
  store ownership. Reach an actual unauthorized file or operation before claiming impact.
- [ ] Identify the current tenant and the site's own upload namespace.
  A site administrator can still cross a boundary into another tenant.
- [ ] Check whether S3 signing and disk cache paths enforce the current site's
  namespace. Test the same object key or cache digest across separate tenants.

## 3. Verify native process containment

- [ ] Inspect the effective image worker sandbox on the deployed kernel and
  revision, including fallback behavior. Configuration names do not prove enforcement.
- [ ] Identify filesystem access, network access, child process restrictions and
  resource limits that remain in force for the decoder operation.
- [ ] Use [Resource exhaustion](resource-limits.md) if the observed outcome is
  worker or memory loss rather than code execution beyond the process boundary.

## Decision gate

- **Destination or file access blocked:** credit the verified boundary for this
  path, then check any demonstrated alternate ingress or independent effect.
- **Decoder crashes inside a verified boundary:** report the observed containment
  and availability impact. A native failure alone does not prove complete RCE.
- **Isolation unknown:** identify the missing deployment evidence. Do not assume
  either successful containment or access beyond it.
- **Boundary crossed:** name the actual destination, file, tenant or capability
  reached and the resulting confidentiality, integrity or availability impact.
