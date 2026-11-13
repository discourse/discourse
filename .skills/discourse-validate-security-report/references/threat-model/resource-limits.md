# Resource exhaustion

Use for expensive requests, parsers, SQL, native workers, remote calls or queues.

## 1. Find reachable work

- [ ] Identify the first expensive operation and minimum attacker access.
- [ ] Trace indirect entry points too. Limits on one route do not protect paths
  that bypass it.
- [ ] Measure work before error responses. A 404 or 400 cannot recover resources
  already consumed.

## 2. Locate bounds before work

- [ ] Check JSON types before RSA parsing. An integer can select key generation.
- [ ] Verify MIME depth and part bounds precede traversal or tree construction.
- [ ] Verify term length and word count bounds precede SQL ranking, and operation
  count bounds precede hashtag bridge or Redis work.
- [ ] Check multiplying parsing, replacement and route recognition costs,
  including dotted secure upload paths.
- [ ] Check connection and total delivery budgets. Read timeouts can reset per byte.
  Verify deadlines and concurrent worker budgets for push and deferred network work.
- [ ] Measure queue delivery cost, retries, concurrency and backlog. A per operation
  bound does not bound aggregate work.

## 3. Quantify capacity loss

- [ ] Account for deployed Nginx limits, application limits, quotas and background
  concurrency. Request rate limits do not bound per request or deferred work.
- [ ] Measure time, CPU or allocations, peak memory and worker capacity as relevant.
  Record input size, attacker cost and rate.
- [ ] Identify affected users, lost function and duration. Do effective limits
  prevent meaningful harm?
- [ ] Compare ordinary inputs when assessing complexity fixes. Regression tests
  do not establish timing or memory behavior.

## Decision gate

- **Isolated slow function:** prove reachable input and capacity loss first.
- **Bounded cost:** show the enforced bound and arithmetic. Neither slowness nor
  a rate limit alone decides validity.
- **Capacity loss:** report users, duration, resource, concurrency and attacker
  cost. Score the consequence, not the slowest isolated benchmark.
