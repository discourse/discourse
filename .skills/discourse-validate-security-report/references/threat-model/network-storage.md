# Network, storage and isolation

Use for SSRF, remote media, upload races, filesystem access, archives, native decoders or multisite.

## 1. Establish where the operation runs

- [ ] Distinguish a browser image request from a server fetch through FinalDestination.
  Browser access to an address does not prove server access to that address.
- [ ] Record the actual server destination and returned data or side effect.
- [ ] For server requests, follow DNS resolution, allowed internal hosts, ports and
  every redirect. **Observed defense:**
  [An allowed host does not authorize every port](https://github.com/discourse/discourse/commit/99cca912ac6f9045c39f2729d4c7239c2282f965) in onebox fetches.
- [ ] Check fresh, cached and warning card output when the claim concerns remote
  media policy. Use [Rendering and transformations](rendering.md) for those paths.

## 2. Follow validated bytes and file paths

- [ ] Compare bytes validated with bytes ultimately stored or consumed. Can the
  actor replace the remote object between those operations?
  **Observed defense:** [Direct S3 uploads](https://github.com/discourse/discourse/commit/8b5e0b152a15b514c53845a9d3e30e3bf259c148) store validated local bytes.
- [ ] Check filesystem containment after normalization, archive entry types and
  store ownership. Reach an actual unauthorized file or operation before claiming impact.
- [ ] Identify the current tenant and the site's own upload namespace.
  A site administrator can still cross a boundary into another tenant.
- [ ] Check signed URLs and cache paths for tenant scope.
  **Observed defenses:** [Site scoped signing](https://github.com/discourse/discourse/commit/69abc7563b765e21af2a6e2cab203d559cafe3af) and per site [disk caches](https://github.com/discourse/discourse/commit/608f43569277acc379ce516a8641e3f41fdd244c).

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
