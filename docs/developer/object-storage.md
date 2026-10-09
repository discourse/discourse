# Object storage provider boundary

This is an incremental provider boundary below `FileStore`. It does
not add GCS/Azure support or make secure-upload transitions atomic.

`FileStore` retains upload naming, multisite layout, URL generation, caching,
and upload-model behavior. An injected `object_storage` handles object operations.
The default adapter is `FileStore::ObjectStorage::S3`, backed by the existing
`S3Helper`; no provider selection setting or new credentials are introduced.

## Implemented slice

`S3Store#store_file`, `copy_file`, `delete_file`, and `download_file` use the adapter.
Temporary-upload promotion copies before deleting the source, as before.
Upload signing, secure-download signing, and multipart operations also use the
adapter. Backup inspection, listing, transfers, deletion, signing, multipart
operations, and temporary-object promotion share it. Missing-upload verification
also lists objects through the adapter. Bucket configuration and the legacy
`object_from_path` escape hatch remain S3-specific.
Visibility updates now go through `set_visibility`; ACL/tag configuration and
SDK permission calls live in the S3 adapter. The old `S3Store` class helpers are
compatibility delegates, not the implementation used by the adapter.
Upload recovery lists original and tombstone keys through the adapter,
preserving original-first ordering, multisite prefixes, and legacy SDK failures.
Restoring a tombstone (a public copy that keeps the source) and downloading over
the public URL stay in `UploadRecovery` as before: neither is an object-storage
operation of its own, so neither belongs on the store. Downloads deliberately do
not switch to authenticated SDK transfers during this extraction.
Avatar-cache copies and upload/optimized-image tombstone moves now use adapter
operations too. The adapter's `remove` operation preserves the existing helper's
tombstone configuration and path resolution. When configured, it copies before
deleting, retains source objects when copying fails, and tolerates missing objects.
These copies preserve legacy bucket-default ACL/tag options, not an added privacy
guarantee. Tombstone lifecycle provisioning remains S3-specific.
Direct-upload creation uses the adapter's explicit key instead of extracting it
from a signed URL. Upload promotion reads size and checksum metadata through
`stat`, including backup promotion, without retaining an SDK object. A missing
object raises the existing download-failure error and follows existing cleanup
and debug-mode behavior. The legacy temporary-upload signing tuple remains available.

| Operation | Arguments | Result |
| --- | --- | --- |
| upload | file, key, visibility, content headers | key and opaque ETag |
| put | file, key, visibility, content headers, optional MD5 checksum | single-request upload returning key and opaque ETag |
| copy | source, destination, visibility, content headers, replace_metadata | key and opaque ETag |
| delete | key, optional exact-key flag | no result required |
| remove | upload path, optional tombstone flag | apply configured tombstone behavior unless disabled, then delete |
| download | key, destination path | file written to destination |
| stat | key | plain metadata, or nil when absent; authorization errors propagate |
| list | prefix, optional starting key | lazy paginated enumeration of plain metadata |
| upload_file | key, source path, visibility, content headers | no result required |
| upload_url | key, expiration | signed PUT URL using bucket-default permissions |
| download_url | key, expiration, optional content disposition | signed URL |
| upload_request | key, visibility, expiration, custom metadata | SignedRequest containing key, signed URL, and required headers |
| create_multipart | key, content type, visibility, custom metadata | upload ID and key |
| presign_multipart_part | upload ID, key, part number | signed URL |
| list_multipart_parts | upload ID, key, page size, starting part number | parts, truncated flag, next marker |
| complete_multipart | upload ID, key, ordered part numbers and ETags | key and opaque ETag |
| abort_multipart | upload ID, key | no result required |
| set_visibility | key, explicit public/private visibility, optional reset flag | legacy S3 error behavior; see below |

Visibility is `:public`, `:private`, or `:bucket_default`, not a provider ACL string.
The last explicitly preserves the legacy backup behavior of omitting ACLs and
tags and relying on bucket policy; it does not guarantee a private bucket.
Headers are
restricted to cache control, content type, content disposition, and content
encoding; callers cannot sneak ACLs or object tags through that argument.
An ETag is opaque, not a portable content checksum.
`ObjectInfo` includes key, size, last-modified time, ETag, and custom metadata.
`stat` loads custom metadata as a hash; `list` leaves it nil (not loaded) to avoid
an extra request per object. Missing checksum metadata still permits the existing
server-computed checksum path; the download size limit is unchanged.

A refusal by the storage service is an `ObjectStorage::ServiceError`;
`UploadNotFound` (a missing upload session), `ObjectNotFound`, and `AccessDenied`
are kinds of it. Transport failures (`ConnectionError`) and missing credentials
(`CredentialsUnavailable`) are `ObjectStorage::Error` but not service errors. The
original SDK exception remains available as `cause`. Missing buckets are not
classified as missing upload sessions. Upload controllers rescue `ServiceError`
for their existing 404/422 responses, as they rescued the SDK's service errors
before; an outage or a credentials misconfiguration still reaches the error
handler as a 500 rather than becoming a quiet validation failure. Invalid arguments still propagate
unchanged. Object inspection and lazy listings also normalize service failures;
`stat` reads the object's metadata with one request and returns nil when absent. Listing
failures on later pages propagate instead of returning an empty or partial result.
Backup listing and upload-URL generation preserve their `BackupStore::StorageError`
boundary for service failures, with the original SDK exception as the direct cause.
Transport and missing-credential failures retain their original SDK type rather
than being newly wrapped. CORS configuration still uses S3 directly and retains
its AWS error rescue.
Uploads, copies, downloads, and deletion also normalize service failures.
`ObjectNotFound` identifies missing transfer objects; missing-object deletion
remains idempotent. Upload-store deletion passes `exact: true`, preserving its
legacy bucket-root key semantics even when a bucket folder is configured.
Backup deletion continues resolving filenames relative to the configured folder;
backup promotion deletes its exact source key only after a successful copy.
SDK aggregate multipart transfer errors become `Error` with
their original per-part details retained in `cause`, rather than classifying a
potentially mixed batch as one missing object or permission failure.
Downloads use the transfer manager inside the adapter, preserve custom backup
failure messages for storage errors, and let local filesystem errors propagate
without relabeling them as remote failures. The legacy `S3Helper#download_file`
wrapper remains unchanged for callers outside the adapter.
The existing `S3Store#download_file` and `S3BackupStore#download_file` APIs wrap
adapter and local filesystem failures in `RuntimeError`, preserving the legacy
download message (including custom backup messages). The adapter's typed error
remains available as the cause; its SDK cause adds one level to that chain.
All adapter operations normalize SDK service errors, SDK-wrapped transport
failures (`ConnectionError`), and missing signing credentials
(`CredentialsUnavailable`), while preserving ordinary argument validation.
The SDK error allowlist is shared across operations, including deferred listing
enumeration. Credential-provider service errors (such as STS failures) retain
their cause and use the generic error unless a more specific mapping applies.
This introduces no retries or retryability promise: a transport failure during a
write does not establish whether the remote operation completed.
Permission service failures are normalized inside the adapter after the existing
unsupported-ACL and missing-object warning cases. The S3Store permission APIs
re-raise the original SDK exception for legacy callers, preserving its
code, request context, and original cause without introducing a cause cycle.
MediaConvert retains its original AWS error diagnostics, including error codes.
Object inspection, copying, permission changes, and temporary-file removal now
go through store operations backed by the adapter. Temporary removal disables
tombstoning while preserving legacy helper path resolution. Cleanup failures
remain warning-only. The conversion API, credentials, and S3 job URLs remain
AWS-specific, and the existing destination-missing log behavior is unchanged.
Configuration/credential-provider initialization errors outside these SDK error
types are not normalized. New adapter APIs expose provider-neutral failures;
legacy store compatibility entry points retain their documented SDK boundaries.

## Compatibility boundaries

The extraction is not yet a drop-in replacement for every plugin-facing API.
The in-tree AWS rescue sites were checked: remaining S3-specific rescues belong
to direct SDK/helper operations or explicit compatibility boundaries, while
migrated controller paths use adapter errors. Download exception class/message
compatibility is now tested against the unchanged legacy helper for both stores,
including real local filesystem failures and successful byte transfers.

Permission updates retain legacy service, transport, and missing-credential
exception types. Their adapter errors remain provider-neutral. Unrelated causes
are not treated as SDK errors. Transport errors retain the SDK's `original_error`
diagnostic without adding an artificial Ruby cause. Exact exception cause chains
and arbitrary external plugin overrides are not a blanket compatibility promise.

Upload-store writes, copies, deletion, tombstone removal, and avatar copies now
also restore original SDK exceptions at the legacy API boundary. The adapter
continues to normalize those failures. Unrelated injected-provider errors keep
their own cause instead of being indiscriminately unwrapped. External-upload
completion accepts both the legacy store's SDK `NotFound` and the adapter's
`ObjectNotFound` inspection error. Backup inspection, upload, deletion, and
promotion now restore original SDK errors too, while retaining adapter operations
and copy-before-delete ordering. Backup listing/upload-URL wrapping now preserves
the legacy service-only boundary and direct SDK cause. Legacy upload-store
signing (`signed_request_for_temporary_upload`, `url_for`, and
`signed_url_for_path`) restores original SDK exceptions; the new
`prepare_direct_upload` entry point keeps provider-neutral failures. Signing
argument errors continue to propagate unchanged. Multipart creation uses
`prepare_multipart_upload` in core upload handling for both uploads and backups.
The legacy `create_multipart` methods delegate to that operation but restore SDK
exceptions. Temporary key generation, private visibility, metadata, and the
backup filename collision check remain unchanged.
Missing-upload verification also restores SDK failures at its legacy public
boundary, including failures during lazy pagination. The temporary verification
table is still removed on failure; adapter listings retain provider-neutral errors.
These listing regressions explicitly select the nil/no-inventory configuration.
The existing inventory selection checks Ruby truthiness, so an empty bucket
string still selects inventory; changing that behavior is outside this extraction.

Legacy store-level `list_multipart_parts`, `complete_multipart`, `abort_multipart`,
and `presign_multipart_part` methods retain their SDK results and exceptions,
including response context, pagination fields, part timestamps, completion
location, version ID, and abort request-charged metadata. Part signing still
returns the helper's URL unchanged. Core controller paths call
`store.object_storage` for these operations and continue using provider-neutral
results and errors. These explicit compatibility entry points are not the API for
new provider-independent callers.

Tombstone removal is compared with the legacy helper across single-site and
multisite configurations, optional bucket folders, custom/empty tombstone prefixes,
and relative/already-prefixed input paths. Injected helper configuration remains
authoritative, even when it differs from site settings. This deliberately retains
legacy prefix quirks instead of silently correcting key layout during extraction.
The `remove` operation is a compatibility seam, not a portable retention policy;
a future provider must define its own equivalent behavior before being enabled.

Do not equate passing targeted tests with full application or plugin parity.

The S3 adapter honors existing ACL/tag settings internally. Those settings are
not yet generalized. Other AWS error behavior, multipart-copy selection, key prefixing,
and signing mechanics remain in `S3Helper`. Adapter multipart listings are plain
hashes and completion returns `Result`, not SDK objects; legacy store methods
remain SDK-backed compatibility entry points for external callers. Multipart
is the first candidate protocol, not a claim that every provider has S3-style
sessions or supports the same expiration limits. This is an extraction seam, not a
finished provider-neutral contract.

Inventory object listing and downloads now use the adapter, including symlink
manifests and compressed CSV data. The inventory reader still owns its AWS
inventory format, bucket configuration, date selection, and verification SQL.
Listing service failures retain their logged-empty behavior, including later
page failures; transport failures retain their SDK type. Downloads retain custom
RuntimeError messages and direct SDK causes, local-file reuse, and decompression.

Local-to-S3 migration listing and transfers now use the adapter. Migration keeps
its configured client, bucket/folder and multisite key selection, size-based skip
logic, dry-run behavior, concurrency, and database remapping. Single-request PUTs
retain MD5 checks and the one-time retry without oversized disposition metadata;
they do not switch to multipart. SDK exceptions are restored at the migration
boundary and worker file handles are closed after each upload (the old loop never
closed them). Listing prints a progress dot per 1,000 keys, S3's page size, as
the paged listing did.

## Deliberately excluded

- Provider configuration/credential initialization and removal of all SDK-object escape hatches.
- Reliable permission transitions and cache revocation. The S3 adapter deliberately
  preserves warning-only behavior for unsupported ACLs and missing objects, and
  propagates other errors. It still updates ACLs and tags in separate requests.
  A failed change can leave remote ACLs and database visibility inconsistent;
  that needs durable reconciliation. Extraction does not make this fail-closed.
- Backup bucket/path configuration, inventory format/configuration, bucket creation, CORS, and lifecycle management (including tombstone expiration).
- Legacy `object_from_path` and SDK-returning multipart methods, retained for compatibility.
- Migration configuration and database remapping, MediaConvert's conversion API and job URLs, and LiveKit.
- GCS/Azure adapters and capability negotiation.

Do not switch production storage based on this boundary alone. A second provider must
exercise the same behavioral tests before treating this interface as settled.
Bucket provisioning/IAM/lifecycle should eventually be deployment concerns, but
this extraction does not remove the existing application's bucket-management behavior.

## Validation

Run the adapter's HTTP request/response tests and existing S3 regressions:

```sh
bundle exec rspec spec/lib/file_store/object_storage/s3_spec.rb \
  spec/lib/file_store/s3_store_spec.rb spec/lib/s3_helper_spec.rb \
  spec/lib/backup_restore/s3_backup_store_spec.rb \
  spec/services/external_upload_manager_spec.rb \
  spec/lib/upload_recovery_spec.rb spec/lib/file_store/to_s3_migration_spec.rb \
  spec/requests/uploads_controller_spec.rb spec/requests/admin/backups_controller_spec.rb
```

Adapter tests use the real AWS SDK with WebMock HTTP fixtures, not stubbed helper
methods. They cover payloads, visibility, metadata replacement, ACL-disabled
configuration, failure propagation, rejected arguments, multipart pagination and
completion, signing without network requests, object metadata, paginated listing,
missing-versus-denied inspection, bucket-default backup transfers, and ACL/tag
updates with preserved warning/error behavior. These are client
contract tests, not acceptance tests against a real object-storage service.

The adapter spec exercises MediaConvert completion against SDK/HTTP fixtures,
including persisted optimized-upload metadata, public/private permissions, and
warning-only cleanup failure. The older completion fixtures now use one stable
store instance, correcting the nil destination paths behind five previously
documented baseline failures.

The inventory expectation now deduplicates screenshot URLs, matching the
report's one-row-per-upload behavior rather than counting theme references.
This corrects three output-comparison failures reproduced before extraction.

The dominant-color backfill specs now save their image fixtures before invoking
the backfill. The image fabricator changes the stored URL in memory after
creation; without saving, a database reload can point at a nonexistent file.
The fixture, model, and local store paths involved were unchanged by extraction.

The expanded regression run passed 982 examples with seed 43132 in the isolated
test container. It includes file stores, multisite storage, helpers/CORS,
inventory, recovery, backup stores/restoration, S3 tasks/jobs, video conversion,
external uploads, configuration checks, upload/backup requests, and
upload/optimized-image/optimized-video models. This is not the full Discourse
suite, browser coverage, or validation against live S3.

## Call-site audit

The audit covers Ruby sources in `app`, `lib`, `plugins`, and `script`. Object
operations in uploads, backups, recovery, inventory, migration, and video
completion now cross the adapter or its store-level compatibility boundary.
This is not a claim that Discourse or its integrations are AWS-independent.

| Remaining S3 reference | Reason it remains |
| --- | --- |
| S3 adapter and S3Helper | Provider implementation and preserved legacy entry points |
| Store `object_from_path` and SDK multipart delegates | Compatibility escape hatches, not the core provider-neutral API |
| Store, migration, and inventory construction | Existing credentials, bucket/folder settings, and client configuration |
| CORS, lifecycle, bucket creation | Existing provider-specific provisioning behavior |
| MediaConvert client, job URLs, and SDK error rescues | AWS conversion service and preserved diagnostics |
| External-upload SDK NotFound rescue | Compatibility with legacy store inspection failures |

Bucket settings, URL layout, inventory format, permissions, and multipart
semantics still need provider-specific design before adding another backend.
No GCS/Azure adapter or production deployment is included in this extraction.
