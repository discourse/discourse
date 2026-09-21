# Testing uploads locally

`disco upload` and `disco import` create real `Upload` records and push real files
into a store. This is how to exercise both paths — a local store and an S3 one —
on a throwaway site, without running a converter against a real forum first.

## 1. Build a corpus

`upload_corpus.rb` writes a directory of synthetic images and attachments plus a
matching IntermediateDB whose `upload_sources` point at them, which is exactly
what the upload run consumes. It needs ImageMagick's `magick`, but no Rails and
no converter run:

```bash
CORPUS_DIR=/tmp/upload_corpus CORPUS_IMAGES=60 CORPUS_ATTACHMENTS=20 \
  ruby migrations/tooling/scripts/benchmarks/upload_corpus.rb
```

You get `/tmp/upload_corpus/corpus.sqlite3` and `/tmp/upload_corpus/files/`.
Everything derives from `CORPUS_SEED`, so the same seed gives you the same bytes
every time. `CORPUS_MAX_ATTACH_MB` controls the largest attachment.

## 2. Local store

Put this in `migrations/importer/config/upload.local.yml` — it is gitignored and
wins over the committed `upload.yml` template:

```yaml
intermediate_db: "/tmp/upload_corpus/corpus.sqlite3"
root_paths:
  - "/tmp/upload_corpus/files"

delete_surplus_uploads: false
delete_missing_uploads: false

site_settings:
  secure_uploads: false
  s3_enable_access_control_tags: false
  enable_s3_uploads: false
  multisite: false
```

`intermediate_db` and `root_paths` are the only required keys; `files_db` and the
download cache derive next to the IntermediateDB, so the run writes
`/tmp/upload_corpus/files.db`.

```bash
RAILS_ENV=development migrations/bin/disco upload
```

Run it against a site you don't mind breaking. Useful flags:

| Flag | What it does |
|------|--------------|
| `--reset` | Deletes files.db and starts over. The download cache is kept, so URLs aren't fetched again. |
| `--fix-missing` | Verifies each upload's file is on the store (and its S3 ACL); broken records are deleted and re-uploaded in the same run. |
| `--optimize` | Precomputes optimized images. |

Use `RAILS_ENV=development`, not `test`: in the test environment `UploadCreator`
skips the image optimization stages, so you would never exercise the expensive
path.

Then look at what the run produced:

```sql
-- files.db
SELECT status, skip_reason, count(*) FROM upload_results GROUP BY 1, 2;
SELECT id, original_filename, url, filesize FROM uploads LIMIT 5;
```

## 3. Import into the site

Point `migrations/importer/config/import.yml` at the same IntermediateDB and a
mappings DB, then:

```bash
RAILS_ENV=development migrations/bin/disco import
```

With `files.db` next to the IntermediateDB the uploads step is a plain column
copy. Check that every source id came back in `mapped.ids`, including
deduplicated ones (several sources with the same sha1 share one upload).

To test **inline mode** instead, make sure no files.db exists (or point
`intermediate_db` at a fresh copy) and configure the `uploads:` section under
`import.yml` with `root_paths`. The import then creates the
uploads itself, straight into the site.

## 4. S3, with MinIO

MinIO is an S3-compatible server; this mirrors what CI does in
`.github/workflows/tests.yml`.

```bash
docker run -d -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
  -e MINIO_DEFAULT_BUCKETS=discoursetest -e MINIO_DOMAIN=minio.local \
  bitnami/minio
```

Buckets are addressed virtual-host style, so both hostnames have to resolve:

```bash
echo "127.0.0.1 minio.local discoursetest.minio.local" | sudo tee -a /etc/hosts
```

On macOS add the IPv6 forms as well (`::1` and `fe80::1%lo0`).

Then swap the `site_settings` block:

```yaml
site_settings:
  secure_uploads: false
  s3_enable_access_control_tags: false
  enable_s3_uploads: true
  s3_upload_bucket: "discoursetest"
  s3_region: "us-east-1"
  s3_access_key_id: "minioadmin"
  s3_secret_access_key: "minioadmin"
  s3_cdn_url: ""
  s3_endpoint: "http://minio.local:9000"
  multisite: false
```

`s3_endpoint` is what makes this point at MinIO rather than AWS. It is applied
like every other key in the block — unconditionally — so leaving it out means
AWS, and an endpoint someone set on the target site can't quietly send a real
migration somewhere else.

You find out immediately whether the store is wired up correctly: the run pushes
a test file through `UploadCreator` before it starts and fails if the upload
doesn't come back with a protocol-relative URL.

Two things to know:

- Start with `s3_enable_access_control_tags: false`. Turn it on to exercise the
  ACL and tagging paths, which is also what `--fix-missing` checks for an
  external store.
- If you want to open an uploaded file in a browser, give the bucket a public
  read policy. `spec/support/system_helpers.rb` does exactly that for the S3
  system specs and can be copied.

## Measuring instead of testing

For throughput rather than correctness, `upload_worker_scaling.rb` drives the
real pipeline at fixed worker counts and can simulate store latency, which is
how the adaptive controller's curves were produced. `upload_creator_profile.rb`
breaks a single `UploadCreator` call into its stages. Both refuse to run unless
`UPLOAD_BENCH_I_KNOW=1` is set, and refuse an S3-backed store unless
`UPLOAD_BENCH_ALLOW_S3=1` is set too.
