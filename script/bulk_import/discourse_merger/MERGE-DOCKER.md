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
- **Preupload both self-hosted sites to Discourse hosting.** Pass both original archives directly. From the checkout root, substitute your backup paths and original source URL.

  ```bash
  MERGE_ENV=script/bulk_import/discourse_merger/docker/merge-env
  "$MERGE_ENV" setup --mode preuploaded --settings /private/uploads_importer.yml --revision "$(git rev-parse HEAD)" \
    --source /backups/source-v20260101000000.tar.gz --source-url https://old.example.test \
    --destination /backups/destination-v20260201000000.tar.gz
  ```

  Setup keeps both backups intact. Each full archive must contain `dump.sql.gz` and one `uploads/<site>/original/` tree. Setup stages each site's SQL dump separately and mounts its originals and available thumbnails read-only at `/mnt/source-uploads` or `/mnt/destination-uploads`. Hosted uploads happen after workbook review.
- **Mix full and SQL-only backups in preuploaded mode.** For example, with a full source and SQL-only destination, use the same command with `--destination /backups/destination-v20260201000000.sql.gz`. Either side can take a SQL-only backup. If that side supplies local files, add `--source-media /path/to/uploads` or `--destination-media /path/to/uploads` as appropriate. Each directory contains `original/`.
- **Preserve remote uploads** with `--mode preserve_remote` and SQL-only backups. For a full archive, first stage `dump.sql.gz` with the original backup basename and the `.sql.gz` extension.
- **External plugins** take one `--plugin https://github.com/OWNER/PLUGIN.git@FULL_COMMIT` per required plugin.

Save the printed run ID. Setup restores and migrates both forums, shows their titles and topic counts, and asks for the destination URL for rewritten links and the namespace for imported IDs. The local review container keeps its loopback address.

For preuploads, give setup the **host** path to your private uploader YAML using `--settings` or enter it at the prompt. Use the [uploader template](../uploads_importer.yml) and confirm the storage values independently with hosting. Setup stages a private copy, resolves the bucket, folder and optional multisite tenant, and displays the read and write locations, region, CDN and access policy. Review each site's action:

| Media available | What to confirm |
|---|---|
| Incoming local files, existing public hosted destination | Supply the destination read prefix in the uploader YAML. Answer yes to retaining that prefix. Setup stages incoming files and checks the retained destination inventory. |
| Local destination files, incoming files already hosted | Prepare the destination. Confirm where the incoming objects are available: at the write target or at a configured source read prefix. A SQL dump alone supplies no file bytes. Keeping arbitrary source URLs in place is unsupported in this mode. |
| Local files for both | Prepare both sites. Setup mounts each archive's upload tree separately. |

Answer the site confirmation after reviewing the choices. Setup saves the complete configuration and exports a fresh workbook with all categories available for review. A resumed run preserves confirmed decisions. If you explicitly provide your own `project/merge.yml` before confirmation, setup uses that file; follow the manual settings instructions below.

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

Choose `docker` for the all-in-one socket defaults or `custom` for your own database connections. During `init`, enter the original source URL, the destination URL for rewritten links, and the short label for imported IDs (the namespace). When reusing a reviewed workbook, match its source and destination origins (including scheme and port), database names, and namespace. Match an omitted namespace by accepting the automated setup default without typing a label. Confirm the site identities. Open `$PROJECT/mappings.xlsx`.

## Review the workbook

From here, use the shell where you defined `merge_cli`. Share `mappings.xlsx` privately because it contains topic titles and group names. Open **Start Here**, edit the yellow cells and keep the generated IDs. For example, to route **Questions** to **Product Support**, select **Use existing category** on **Category Mapping** and pick **Product Support** under **Discussions go to**. Use **Topic Exceptions** for individual discussions. Review group memberships and staff roles, then save the workbook at the same path.

If you already have a reviewed workbook for the same forums and matching project settings, copy it over the generated `mappings.xlsx` and make sure the application user can read it. You can skip editing it again.

To edit from a workstation with authorized SSH access, substitute the Docker host and printed project path, then run these commands **on the workstation** (use a private working directory):

```bash
HOST=root@your-migration-host
PROJECT=/var/discourse/merge-runs/YOUR_RUN_ID/project
scp "$HOST:$PROJECT/mappings.xlsx" ./mappings.xlsx
# Edit and save mappings.xlsx, then return it.
scp ./mappings.xlsx "$HOST:$PROJECT/mappings.next.xlsx"
```

On the Docker host, publish the returned workbook and check it:

```bash
docker exec "$RUN_ID" sh -ec 'cd /shared/merge-project; chown discourse:discourse mappings.next.xlsx; chmod 600 mappings.next.xlsx; mv mappings.next.xlsx mappings.xlsx'
merge_cli validate-workbook
```

The check reads the workbook against the current forum settings and restored inventory. Matching project settings do not establish backup-file identity. A reused workbook supplies mapping decisions only. Preparation repeats validation before hosted writes. Start each fresh rehearsal with fresh receipts and approvals.

For `copy` and `preserve_remote`, continue to [plan and apply](#plan-and-apply). For `preuploaded`, prepare media first.

## Prepare hosted uploads

With guided setup, use the printed command:

```bash
merge_cli prepare-uploads --settings /shared/private/hosted-review-uploads.yml
```

The settings file supplies the hosted storage configuration. The project records the reviewed target. If they disagree, preparation stops before contacting S3. With `multisite: false`, the write location is `s3://` followed by `site_settings.s3_upload_bucket` (bucket and optional folder). With multisite enabled, the resolver appends `uploads/<multisite_db_name>`. Top-level `preupload_read_prefixes` supplies separate read locations by site.

**Manual configuration or an existing container.** In a manually authored project set `preupload_locations.write` to the confirmed write location and `preupload_locations.read_prefixes` to the configured side-specific read prefixes. Set `preserve_destination_uploads: true` only to retain public destination files in place. Set each local media root to its container mount (`source_upload_root: /mnt/source-uploads` or `destination_upload_root: /mnt/destination-uploads`). Stage the private file from the **host**:

```bash
SETTINGS=/absolute/path/to/private/uploads_importer.yml
docker exec "$RUN_ID" install -d -m 0700 -o discourse /shared/private
docker cp "$SETTINGS" "$RUN_ID":/shared/private/settings.next.yml
docker exec "$RUN_ID" sh -ec 'cd /shared/private; chmod 600 settings.next.yml; chown discourse:discourse settings.next.yml; mv settings.next.yml hosted-review-uploads.yml'
docker exec -u discourse "$RUN_ID" test -r /shared/private/hosted-review-uploads.yml
```

A successful readability check exits silently. Use the preparation command above. Snapshots of this storage contain the settings file and require private storage.

### Investigate a local media mismatch

Use the side and ID printed in the error. For example:

```bash
merge_cli inspect-uploads --side source --id 3594
```

Omit `--id` to list discrepancies for the entire local tree represented in that site's database. The diagnostic reports missing local files, paths, recorded and actual sizes, SHA-1 values, and the SHA-256 of the actual bytes. IDs are per table; check the table name. Missing local thumbnails may be regenerated during preparation. This check reads the database and local files without contacting S3 or creating upload receipts.

Compare the file with an authoritative original. If the bytes are wrong, preserve the original backup and supply a corrected media tree. For a running Docker project, copy the mounted tree to a fresh directory under `/shared` and replace only the affected file. For a source correction, substitute the reported relative key and the path to the verified file:

```bash
KEY=original/REPORTED_RELATIVE_PATH
CORRECT=/absolute/path/to/verified/file
docker exec -u discourse "$RUN_ID" sh -ec 'umask 077; mkdir /shared/merge-project/corrected-source; cp -R /mnt/source-uploads/. /shared/merge-project/corrected-source/'
docker cp "$CORRECT" "$RUN_ID":/shared/merge-project/correction.next
docker exec "$RUN_ID" sh -ec 'chown discourse:discourse /shared/merge-project/correction.next; chmod 600 /shared/merge-project/correction.next; mv /shared/merge-project/correction.next "/shared/merge-project/corrected-source/$1"' sh "$KEY"
```

Set `source_upload_root` to `/shared/merge-project/corrected-source` in this run's configuration and inspect the ID again. For destination files use the destination mount, key and root. Reuse the private corrected tree for subsequent corrections.

If the original's size matches and independent review establishes that the actual bytes are intended, record a **fresh** approval for that original only:

```bash
merge_cli approve-original --side source --id 3594 --sha256 REVIEWED_ACTUAL_SHA256
```

Review the path, evidence and storage target printed by the command before answering yes. Size mismatches, thumbnail exceptions and collisions with the other site's recorded original require correction or investigation. After resolving the discrepancy, rerun preparation with the same settings.

## Plan and apply

1. Run `merge_cli plan`. Read `preview.md` in the project directory. Check routes, omissions, new staff roles, group access expansions and media locations. After edits, rerun planning and review the new checksum.
2. Freeze the source. The automated Docker workflow can snapshot the destination database, Redis, local storage, and project together. Substitute the SHA-256 you reviewed. The tool saves Redis, takes PostgreSQL and Redis down during the copy, checks the copied plan, brings both services back and waits for readiness. Web and workers stay stopped.

   ```bash
   REVIEWED_HASH=SHA256_FROM_PLAN
   "$MERGE_ENV" snapshot "$RUN_ID" --plan-sha256 "$REVIEWED_HASH"
   ```

3. Run `merge_cli apply --plan-sha256 "$REVIEWED_HASH"`. Include `--approve-access-changes` only after approving the reported expansions. Apply changes the restored destination and runs verification.

If apply fails after mutation begins, keep the logs. On the Docker host restore the complete reviewed snapshot:

```bash
"$MERGE_ENV" recover "$RUN_ID" --plan-sha256 "$REVIEWED_HASH" --yes
```

Recovery preserves the failed storage and project at the printed private path, restores a clean pre-apply project and restarts the isolated destination. After an interruption repeat the same recovery command. Review the failure before retrying. In a custom environment use an equivalent cold snapshot and recovery procedure for all four components.

## Export the Discourse backup

After **Apply verified**, run `merge_cli report` for the private report and account outcomes CSV. Open the destination shell from the host:

```bash
docker exec -it -u discourse -w /var/www/discourse "$RUN_ID" bash
```

Run the **exact backup command printed by apply or verify**. Copy mode produces a full backup; preuploaded mode produces SQL-only; preserve-remote uses SQL-only when destination local uploads are absent. A SQL-only backup depends on the configured media locations.

Record the new filename under `/shared/backups/default/`. For automated setup, in the **host shell** substitute the exact new filename printed by the backup command:

```bash
EXPORT=EXACT_NEW_BACKUP_FILENAME
RUN_DIR=/var/discourse/merge-runs/$RUN_ID
install -d -m 0700 "$RUN_DIR/exports"
sha256sum "$RUN_DIR/runtime/destination/backups/default/$EXPORT"
mv -n -- "$RUN_DIR/runtime/destination/backups/default/$EXPORT" "$RUN_DIR/exports/$EXPORT"
sha256sum "$RUN_DIR/exports/$EXPORT"
```

Use a new export filename. Verify that the two checksums match and hand off the backup from the printed `exports/` location. Both original backup files remain in their input directories.

## Resume or clean up an automated run

On the host, use `"$MERGE_ENV" list` to find a run and `"$MERGE_ENV" resume "$RUN_ID"` after an interrupted setup. Build and restore logs are in the private run directory. Before retiring it, move exports and recovery snapshots outside `runtime/`. The project, workbook, reports and run logs survive cleanup.

```bash
"$MERGE_ENV" cleanup "$RUN_ID"        # Preview removal and retained paths
"$MERGE_ENV" cleanup "$RUN_ID" --yes  # Retire the listed resources
```
