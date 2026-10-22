# Live sentiment comparison: TypeSafe Jev versus Snorlax d3

Measured 2026-10-22, 04:27:22–04:27:27 UTC, using TypeSafe model alias
`jev-latest`. All responses identified the serving model as **`jev-1.14.0`**.

## Method and credential handling

- Reused the ten topics and prepared text from [d3 round 2](sentiment-d3-round-2.md),
  including the 1,208-word, 2,366-word and deliberately capped 3,591-word cases.
- Verified the actual serialized `state` **and** `questions` in all 20 audit
  requests against their corresponding d3 requests; all were identical. Both
  providers received the same 3-way sentiment and 28-way emotion questions.
- Used the existing TypeSafe Decisions adapter with a transient `DecisionModel`
  and transient `AiSecret`. The credential was read from the user-authorized
  local term-llm configuration, never printed, copied into artifacts, or saved
  in Discourse. No new model or secret database records were created.
- Requests were sequential, sentiment then emotion, with one allowed attempt
  each; no automatic retries. All 20 returned HTTP 200 with non-refusal answers.
- Results are retained in the benchmark artifact and audit logs, **not** written
  over the existing `ClassificationResult` rows. Verified all d3 rows and both
  site's selected decision-model IDs remained unchanged.

## Comparable latency metric

Use `AiApiAuditLog.duration_msecs` for both providers and sum the sentiment and
emotion requests per post. This shared timer excludes classification-result
persistence and the runner's result collection. Earlier d3 headline timings
included result persistence and are therefore slightly higher.

| Case / topic | Body words | Actual input words including title | d3 combined request time | Jev combined request time | Observed ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| [Sarcasm, 39](https://classify-sentiment.dev.home.arpa/t/39) | 487 | 495 | 2.283 s | 0.482 s | 4.74× |
| [Quoted criticism, 40](https://classify-sentiment.dev.home.arpa/t/40) | 464 | 472 | 2.242 s | 0.454 s | 4.94× |
| [Restrained complaint, 41](https://classify-sentiment.dev.home.arpa/t/41) | 1,208 | 1,216 | 2.764 s | 0.504 s | 5.48× |
| [Neutral runbook, 42](https://classify-sentiment.dev.home.arpa/t/42) | 3,591 | 3,000, capped | 4.751 s | 0.546 s | 8.70× |
| [Recovery relief, 43](https://classify-sentiment.dev.home.arpa/t/43) | 2,366 | 2,373 | 4.163 s | 0.498 s | 8.36× |
| [Migration anxiety, 44](https://classify-sentiment.dev.home.arpa/t/44) | 513 | 520 | 2.289 s | 0.485 s | 4.72× |
| [Remorse, 45](https://classify-sentiment.dev.home.arpa/t/45) | 483 | 490 | 2.255 s | 0.453 s | 4.98× |
| [Remembrance, 46](https://classify-sentiment.dev.home.arpa/t/46) | 487 | 494 | 2.259 s | 0.505 s | 4.47× |
| [Playful teasing, 47](https://classify-sentiment.dev.home.arpa/t/47) | 504 | 511 | 2.282 s | 0.452 s | 5.05× |
| [Bittersweet handover, 48](https://classify-sentiment.dev.home.arpa/t/48) | 527 | 534 | 2.278 s | 0.480 s | 4.75× |

| Aggregate | d3 | Jev |
| --- | ---: | ---: |
| Mean combined request time/post | 2.7566 s | 0.4859 s |
| Median combined request time/post | 2.2825 s | 0.4835 s |
| Range | 2.242–4.751 s | 0.452–0.546 s |
| Approximately 500-word subset mean | 2.2697 s | 0.4730 s |
| Sum of the 20 request durations | 27.566 s | 4.859 s |

The mean observed endpoint-latency ratio is **5.67×** in Jev's favor. Jev's
separately measured combined call wall time, including local setup/logging and
result collection but no `ClassificationResult` persistence, averaged 0.499 s.

These were separate sequential runs, not an interleaved randomized load test.
Network location, serving infrastructure, load and caching may affect the
comparison; this does not isolate intrinsic model compute or measure capacity.
No dollar-cost comparison was made.

## Semantic results

Percentages are model outputs, not calibrated confidence or evidence of accuracy.

| Case | Jev sentiment | Jev strongest emotions | Assessment against the text and d3 |
| --- | --- | --- | --- |
| Sarcasm | Negative 99% | Annoyance 79%, anger 11% | Fits final criticism; d3 also negative but retains admiration/approval from the setup. |
| Quoted criticism | Positive 100% | Gratitude 94% | Fits author gratitude rather than the quoted attack; both models get the distinction. |
| Restrained complaint | Negative 100% | Disapproval 69%, disappointment 18%, annoyance 11% | Appropriate; d3 gives disapproval 38% with a large neutral component. |
| Neutral runbook | Neutral 100% | Neutral 100% | Appropriate for the supplied capped procedural text; both models fit. |
| Recovery relief | Positive 100% | Relief 79%, gratitude 20% | Fits present relief; d3 emphasizes gratitude more. Both are reasonable readings. |
| Migration anxiety | Negative 100% | Nervousness 82%, fear 18% | Fits; both distinguish worry from anger. |
| Remorse | Negative 100% | Remorse 65%, embarrassment 35% | Fits; d3 reverses their order, which is also supported by the wording. |
| Remembrance | Negative 92%, positive 7%, neutral 1% | Grief 67%, sadness 30% | Closer to the intended sorrowful mood than d3's positive 65%; d3 may be reading warm evaluative stance. |
| Playful teasing | Positive 100% | Amusement 63%, joy 37% | Fits affectionate banter; both models succeed. |
| Bittersweet handover | Positive 93%, neutral 4%, negative 3% | Relief 43%, sadness 26%, pride 22%, gratitude 9% | Better representation of sadness than d3's 7%, but sentiment remains strongly positive for both. |

### Useful differences

- Jev's grief/sadness result is more consistent with the intended emotional
  valence of the memorial. That does not settle the general distinction between
  felt mood and warm appraisal of the subject; the prompt still needs a clear
  product interpretation before calling one reading objectively wrong.
- In the handover, Jev sadness (0.26) exceeds the report's 0.1 cutoff; d3 sadness
  (0.071) does not. However, Jev gratitude (0.09) now falls below that cutoff,
  while d3 gratitude (0.308) is included. Different distributions change which
  secondary emotions the dashboard shows; this is not strict dominance.
- Jev drops positive setup emotions from the sarcastic complaint more decisively,
  which fits final-stance interpretation. More extreme scores alone do not
  establish better model calibration.

### Output-quality cautions

Jev returns sparse, rounded values, including exact zeros and ones. Seven of ten
sentiment maps are one-hot. These values should not be treated as literal
certainty or compared numerically with d3's smoother probabilities as though
both were calibrated on the same scale.

Two Jev emotion maps (quoted criticism and the restrained complaint) sum to
**0.99**, not 1.00. All other emotion maps and all sentiment maps sum to 1.00.
This looks consistent with rounded output, but the shared parser does not enforce
or renormalize probability sums. No normalization was applied in this benchmark.

## Conclusion

On this small synthetic English set, Jev is materially faster and offers useful
semantic improvements on the grief and mixed-emotion examples. Both models
handle the straightforward cases, attribution, anxiety, remorse and playful
teasing well. Both still compress the bittersweet handover into strongly positive
sentiment. This supports further testing of Jev, not a representative accuracy
claim or a silent production-model switch.

An independent reviewer inspected both sets of outputs and texts and agreed with
the main qualitative conclusions and the need to avoid calibration claims.

## Artifacts

- [Jev timings, full distributions and audit IDs](evaluations/sentiment-jev-2026-10-22-results.json)
- [Shared input texts and predetermined expectations](evaluations/sentiment-d3-2026-10-22-round2-inputs.json)
- [d3 baseline measurements](evaluations/sentiment-d3-2026-10-22-round2-results.json)
