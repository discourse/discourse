#!/usr/bin/env bash
set -euo pipefail
cd /var/www/discourse
export RAILS_ENV=production DISCOURSE_HOSTNAME=merge.example.test DISCOURSE_DB_HOST=/var/run/postgresql DISCOURSE_DISABLE_EMAILS=yes MERGE_FIXTURE=1
project=/tmp/member-review-project
install -d -o discourse -g discourse -m 0700 "$project"
cat > "$project/merge.yml" <<'YAML'
source: { dbname: fixture_source, host: /var/run/postgresql, user: discourse }
destination: { dbname: discourse, host: /var/run/postgresql, user: discourse }
source_url: https://merge.example.test
destination_url: https://merge.example.test
namespace: fixture
upload_mode: copy
source_upload_root: /tmp/source-uploads
destination_upload_root: /shared/uploads/default
include_private_messages: false
import_tags: false
YAML
cp -a /shared/uploads/default /tmp/source-uploads
for stage in source destination; do
  db=discourse
  if test "$stage" = source; then db=fixture_source; fi
  sudo -HEu discourse env DISCOURSE_DB_NAME="$db" FIXTURE_STAGE="$stage" bundle exec rails runner /fixture/member_review.rb
done
cli() {
  sudo -HEu discourse bundle exec ruby script/bulk_import/discourse_merger/cli.rb "$@" --directory "$project"
}
cli export
sudo -HEu discourse bundle exec ruby -rcsv -e '
  path = ARGV.fetch(0)
  rows = CSV.read(path, headers: true)
  rows.each do |row|
    if row["source_path"] == "Uncategorized"
      row["action"] = "reuse"
    else
      row["action"] = "exclude"
      row["destination"] = nil
    end
  end
  File.write(path, rows.to_csv)
' "$project/mappings/categories.csv"
cli plan
reviewed=$(sha256sum "$project/plan.json" | cut -d" " -f1)
cli apply --plan-sha256 "$reviewed"
cli verify
cli report
cp "$project/account-outcomes.csv" /tmp/first-report.csv
cli report
cmp /tmp/first-report.csv "$project/account-outcomes.csv"
sudo -HEu discourse bundle exec ruby -rcsv -e '
  rows = CSV.read(ARGV.fetch(0), headers: true).map(&:fields)
  expected = [
    ["Before","FinalName","Matched by email","true"], ["Second","FinalName","Matched by email","true"],
    ["KeptName","KeptName","Matched by email","false"], ["Unrelated","Unrelated_2","Created after username collision","true"]
  ]
  abort "Unexpected account outcomes: #{rows.inspect}" unless rows == expected.sort
' "$project/account-outcomes.csv"
