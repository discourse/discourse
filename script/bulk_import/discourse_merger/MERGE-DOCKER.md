# Run a Discourse merge

Choose one setup path below. Both produce a private project with `merge.yml` and an editable `mappings.xlsx`. Keep backups, credentials and project files outside the checkout. [Merge outcomes and upload modes](README.md)

## Automated Docker setup

**Prerequisites.** Run as root on a Linux host with Python 3.9+, Git, GNU coreutils, a local Docker daemon and the standard all-in-one launcher (default `/var/discourse`). Have both native backups on the host and space for the image, restored databases, prepared source, media, recovery snapshot and export. Check out a pushed Discourse core commit that the launcher can fetch, contains the merger and its workbook dependencies, and supports both backups’ migrations and plugins. [Discourse installation](../../../docs/INSTALL.md)

From the **checkout root on the Docker host**, substitute the two backup paths and the original source URL. Keep the backup filenames and version suffixes intact.

```bash
MERGE_ENV=script/bulk_import/discourse_merger/docker/merge-env
"$MERGE_ENV" setup --revision "$(git rev-parse HEAD)" \
  --source /backups/source-v20260101000000.tar.gz --source-url https://old.example.test \
  --destination /backups/destination-v20260201000000.tar.gz
```

- **Local uploads** use the default `copy` mode. Include the files in the backups.
- **Remote uploads** use `--mode preserve_remote` or `--mode preuploaded` with SQL-only `.sql.gz` backups. For a full archive, extract `dump.sql.gz` and give it the original backup basename with the `.sql.gz` extension. For preuploads, add `--source-media /path/to/uploads` or `--destination-media /path/to/uploads` for each side supplying files. Each directory contains `original/` and is mounted read-only.
- **External plugins** take one `--plugin https://github.com/OWNER/PLUGIN.git@FULL_COMMIT` per required plugin.

Save the printed run ID. Setup restores both sites into isolated storage and asks you to confirm their titles and topic counts. For a local rehearsal, confirm them to let setup run `init` and `export-workbook`. It prints the workbook path and stops for review.

<details>
<summary>Using a hosted review or final destination URL?</summary>

Choose the intended URL before confirming the sites. Setup defaults to `http://merge.example.test:PORT` with an allocated loopback port. The project’s `destination_url` controls rewritten links. The workbook binds to the forum URLs, namespace and database names. Reusing upload receipts also requires matching forum URLs.

At the confirmation prompt, use a second host shell to create a complete `merge.yml` in the new run’s `project/` directory (default `/var/discourse/merge-runs/RUN_ID/project/`). Setup uses this file if present. For example, for a hosted preupload with local source files:

```yaml
source: { dbname: incoming_forum, host: /var/run/postgresql, user: discourse }
destination: { dbname: discourse, host: /var/run/postgresql, user: discourse }
source_url: https://old.example.test
destination_url: https://review.example.test
namespace: incoming
upload_mode: preuploaded
source_upload_root: /mnt/source-uploads
```

Use the actual forum URLs, upload mode, content choices and mounted paths for this run. For `copy`, use `/shared/incoming-uploads` and `/shared/uploads/default` as the source and destination upload roots. Make the file readable by the container’s `discourse` user, then confirm the restored sites. The local container keeps its loopback binding.

</details>

Define this helper in the **host shell**, substituting your run ID, then continue to [workbook review](#review-the-workbook).

```bash
RUN_ID=merge-0123456789abcdef
merge_cli() {
  docker exec -it -u discourse -w /var/www/discourse "$RUN_ID" \
    bundle exec ruby script/bulk_import/discourse_merger/cli.rb "$@" --directory /shared/merge-project
}
```

## Bring your own environment

Restore and migrate both backups on the same build and plugins. Make the prepared source database readable from the destination application. Point Rails at the restored destination database and isolated Redis. Stage the media for your chosen mode and install the `generic_import` bundle group.

Keep PostgreSQL and Redis ready, disable email, and stop supervised Unicorn or Pitchfork and Sidekiq. The application user must see `down:` from `sv status` for each configured web and worker service under `/etc/service`. Grant traversal on the supervise directory, read access to `status` and write access to the `ok` FIFO. Keep service control with root.

In the **destination Discourse checkout as the application user**, choose a writable private project path and run:

```bash
PROJECT=/absolute/path/to/private/merge-project
merge_cli() {
  RAILS_ENV=production DISCOURSE_DISABLE_EMAILS=yes bundle exec ruby \
    script/bulk_import/discourse_merger/cli.rb "$@" --directory "$PROJECT"
}
merge_cli init
merge_cli export-workbook
```

Choose `docker` for the all-in-one socket defaults or `custom` for your own database connections. Enter the original source URL and intended destination URL during `init`. Confirm the site identities. Open `$PROJECT/mappings.xlsx`.

## Review the workbook

From here, use the shell where you defined `merge_cli`. Share `mappings.xlsx` privately because it contains topic titles and group names. Open **Start Here**, edit the yellow cells and keep the generated IDs. For example, to route **Questions** to **Product Support**, select **Use existing category** on **Category Mapping** and pick **Product Support** under **Discussions go to**. Use **Topic Exceptions** for individual discussions. Review group memberships and staff roles, then save the workbook at the same path.

For `copy` and `preserve_remote`, continue to [plan and apply](#plan-and-apply). For `preuploaded`, prepare media first.

## Prepare hosted uploads

Confirm the write location, any retained read prefixes, region, CDN and ACL/tag policy independently with hosting. For a public hosted destination whose files should stay in place, set these keys in the project’s `merge.yml`. Replace the example prefixes with the confirmed values.

```yaml
preserve_destination_uploads: true
preupload_locations:
  write: s3://example-bucket/forums/uploads/review
  read_prefixes:
    destination: s3://example-bucket/forums/uploads/retained
```

Configure the private uploader YAML with the hosted settings and, for this example, set its top-level `preupload_read_prefixes.destination` to the retained location. Supply the path readable by the application user **inside the destination environment**. This step checks the locations against the project before contacting S3 and can write missing objects. [Uploader settings template](../uploads_importer.yml)

```bash
merge_cli prepare-uploads --settings /path/to/private/uploads_importer.yml
```

After fixing a missing file or setting, rerun preparation. For a fresh project, reuse a closed receipt database from an idle project only when both forum URLs, preservation mode, storage locations, region, CDN and access policy match. A changed target needs fresh receipts and approvals.

## Plan and apply

1. Run `merge_cli plan`. Read `preview.md` in the project directory. Check routes, omissions, new staff roles, group access expansions and media locations. After edits, rerun planning and review the new checksum.
2. Freeze the source. Take a recovery snapshot of the destination database, Redis, local storage **and the project with the reviewed plan**. Automated setup mounts the project separately. For a filesystem copy, save Redis and stop PostgreSQL and Redis during the copy. Verify the copied plan’s checksum, restart both services, and wait for PostgreSQL readiness and a Redis response. Keep web and workers stopped.
3. Run `merge_cli apply --plan-sha256 REVIEWED_HASH` using the checksum from step 1. Include `--approve-access-changes` only after approving the reported expansions. Apply changes the restored destination and runs verification. If it fails after mutation begins, retain the logs, restore the complete snapshot and retry from a fresh project.

## Export and test

After **Apply verified**, run `merge_cli report` for the private merge report and account outcomes CSV in the project directory. Run the printed backup command in the destination checkout as the application user. With automated setup, open that shell from the host using `docker exec -it -u discourse -w /var/www/discourse "$RUN_ID" bash`. Use the indicated backup type. A SQL-only export needs access to the configured media hosts.

Restore the exact export on a separate test site and start its web services. Open a routed topic, an incoming image and thumbnail, a retained attachment and a matched avatar. Check a restricted topic with an authorized account and a signed-out visitor. Record the backup filename and results before deciding on production cutover. To forward old bookmarks, use the run’s `redirects.json` topic map when configuring redirects on the old domain.

## Resume or clean up an automated run

On the host, use `"$MERGE_ENV" list` to find a run and `"$MERGE_ENV" resume "$RUN_ID"` after an interrupted setup. Build and restore logs are in the private run directory. Before retiring it, move exports and recovery snapshots outside `runtime/`. The project, workbook, reports and run logs survive cleanup.

```bash
"$MERGE_ENV" cleanup "$RUN_ID"        # Preview removal and retained paths
"$MERGE_ENV" cleanup "$RUN_ID" --yes  # Retire the listed resources
```
