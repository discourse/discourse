# Resource exhaustion

Use for expensive requests, parsers, SQL, native workers, remote calls or queues.

## 1. Find reachable work

- [ ] Identify the first expensive operation and the actor's minimum access.
- [ ] Follow indirect ingress, such as search routing a URL term, not just requests
  sent directly to the affected route.
- [ ] Measure work even when the final response is an error. A 404 or 400 does not
  recover CPU time, memory or worker capacity already spent.

## 2. Locate the bound before the work

- [ ] Check JSON types before RSA parsing. An integer can select key generation
  instead of public key parsing.
- [ ] Check MIME depth and total parts before traversal or building the full tree.
  See the [MIME limits](https://github.com/discourse/discourse/commit/8cd3007eb0a031e2b37b873f5c7efb2737d6e9d2).
- [ ] Check term length and word count before SQL ranking, and operation count
  before hashtag bridge or Redis work.
- [ ] Check repeated parsing, replacement and route recognition for input that
  multiplies work. See the [secure upload routing fix](https://github.com/discourse/discourse/commit/e366aa5ec10064f74f2e7aaae550e6ad97e9b274).
- [ ] Check outbound connection and total delivery budgets. An idle read timeout
  can reset on each byte. See the [push delivery budgets](https://github.com/discourse/discourse/commit/de5a6f749839277f9244e430595806ebabf369f3).
- [ ] For queues, measure per delivery cost, retry behavior, concurrency and backlog.
  A bound on one operation does not establish a bound on aggregate work.

## 3. Quantify actual capacity loss

- [ ] Account for Nginx rate limits, application limits, quotas and background
  concurrency in the deployed configuration. Request rate limits alone do not
  bound one accepted request or a deferred job.
- [ ] Measure elapsed time, CPU or allocations, peak memory and affected worker
  capacity as relevant to the claim. Record input size and attacker cost or rate.
- [ ] Identify who loses which function, for how long, and whether limits keep
  the effect below meaningful impact.
- [ ] Compare ordinary inputs too when assessing a proposed complexity fix.
  Passing regression tests do not establish timing or memory behavior.

## Decision gate

- **Only an isolated slow function:** establish reachable input and capacity loss
  before claiming availability impact.
- **Effective controls keep the cost bounded:** show the bound and arithmetic.
  Do not assume either that all slowness is a vulnerability or that a rate limit
  makes arbitrary per request cost safe.
- **Capacity loss demonstrated:** report affected users, duration, resource,
  concurrency and attacker cost. Score that consequence rather than the slowest
  isolated benchmark.
