# Network, storage and isolation

Use for SSRF, remote media, upload races, filesystem access, archives, native decoders or multisite.

## 1. Locate the operation

- [ ] Distinguish browser loads from server fetches. Identify each server client's
  effective SSRF controls, including FinalDestination where used. Browser access
  does not prove server access.
- [ ] Record the actual destination and returned data or side effect.
- [ ] Trace DNS, internal host exceptions, ports and every redirect. Can host
  exceptions permit unintended ports, including through onebox redirects?
- [ ] For media policy, check fresh, cached and warning cards with
  [Rendering](rendering.md).

## 2. Follow bytes and paths

- [ ] Compare validated bytes with stored or consumed bytes. Can the actor replace
  a remote object between steps? Trace direct S3 completion through validation,
  hashing, storage and deduplication.
- [ ] Check containment after path normalization, archive entry types and store
  ownership. Demonstrate unauthorized file access or an operation before claiming harm.
- [ ] Identify tenant and upload namespace. Site administrators can still cross
  tenant boundaries.
- [ ] Check S3 signing and disk cache namespace enforcement. Test the same object
  key or digest across tenants.

## 3. Verify process containment

- [ ] Inspect the deployed worker sandbox, kernel, revision and fallback behavior.
  Configuration names do not prove enforcement.
- [ ] Check decoder filesystem, network, child process and resource restrictions.
- [ ] Use [Resource exhaustion](resource-limits.md) for worker or memory loss
  without demonstrated escape.

## Decision gate

- **Access blocked:** credit the verified boundary, then assess demonstrated
  alternate paths or independent effects.
- **Contained decoder crash:** report containment and availability impact.
  Native failure alone is not complete RCE.
- **Unknown isolation:** identify missing evidence. Assume neither containment nor escape.
- **Boundary crossed:** name the destination, file, tenant or capability and CIA impact.
