# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/merger"

RSpec.describe BulkImport::DiscourseMerge::ContentTransfer, type: :request do
  fab!(:member) { Fabricate(:user, active: true) }
  fab!(:discussion_post, :post)
  let(:destination) { ActiveRecord::Base.connection.raw_connection }
  let(:source) { PG.connect(destination.conninfo_hash.compact_blank.merge(dbname: "postgres")) }

  after { source.close }

  def source_row(record, **changes)
    klass = record.class
    columns = klass.columns
    schema = columns.map { |c| "#{PG::Connection.quote_ident(c.name)} #{c.sql_type}" }.join(",")
    source.exec("CREATE TEMP TABLE IF NOT EXISTS #{klass.table_name} (#{schema})")
    projection =
      columns
        .map do |c|
          "#{PG::Connection.quote_ident(c.name)}::text AS #{PG::Connection.quote_ident(c.name)}"
        end
        .join(",")
    row =
      destination
        .exec_params("SELECT #{projection} FROM #{klass.table_name} WHERE id=$1", [record.id])
        .first
        .merge(changes.stringify_keys)
    source.copy_data("COPY #{klass.table_name} FROM STDIN", PG::TextEncoder::CopyRow.new) do
      source.put_copy_data(row.values_at(*columns.map(&:name)))
    end
  end

  it "authenticates the mapped account and verifies its expiry without storing credential values in the ledger" do
    password = "Fictional-harbor-login-123"
    original = Fabricate(:user, password: password)
    credentials = original.user_password
    source_row(credentials, id: 3, user_id: 73)
    member.user_password&.destroy!
    ids = {}
    decisions = {
      "user_passwords" => [
        { "id" => 3, "action" => "copied", "refs" => { "user_id" => ["users", 73] } },
      ],
    }
    transfer =
      described_class.new(source, destination, { users: { 73 => member.id } }, {}, nil, ids)
    transfer.copy(decisions)
    expect(transfer.verify(decisions)).to eq("user_passwords" => { "copied" => 1 })
    expect(ids.fetch("user_passwords")).to eq(3 => member.reload.user_password.id)
    EmailToken.confirm(Fabricate(:email_token, user: member).token)
    post "/session.json", params: { login: member.username, password: password }, xhr: true
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["error"]).to be_nil
    expect(session[:current_user_id]).to eq(member.id)
    original.user_password.update_columns(password_expired_at: 1.day.ago)
    source.exec("TRUNCATE user_passwords")
    source_row(original.user_password, id: 3, user_id: 73)
    expect { transfer.verify(decisions) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /password_expired_at/,
    )
    member.user_password.update_columns(
      password_expired_at: original.user_password.password_expired_at,
    )
    expect(member.reload.password_expired?(password)).to eq(true)
    expect(transfer.verify(decisions)).to eq("user_passwords" => { "copied" => 1 })
  end

  it "serves copied aliases and published pages through Core routes and preserves an occupied alias" do
    SiteSetting.enable_page_publishing = true
    occupied = Permalink.create!(url: "help/original", user: member)
    source_row(occupied, id: 7, url: "help/previous", user_id: nil, post_id: 73)
    page = PublishedPage.create!(topic: Fabricate(:topic), slug: "older-page", public: false)
    source_row(page, id: 2, topic_id: 71, slug: "harbor-manual")
    decisions = {
      "permalinks" => [
        { "id" => 7, "action" => "copied", "refs" => { "post_id" => ["posts", 73] } },
        { "id" => 8, "action" => "skipped", "reason" => "kept destination alias" },
        { "id" => 9, "action" => "reused", "source_target" => 7 },
      ],
      "published_pages" => [
        { "id" => 2, "action" => "copied", "refs" => { "topic_id" => ["topics", 71] } },
      ],
    }
    transfer =
      described_class.new(
        source,
        destination,
        { posts: { 73 => discussion_post.id }, topics: { 71 => discussion_post.topic_id } },
        {},
        nil,
        {},
      )
    transfer.copy(decisions)
    expect(transfer.verify(decisions)).to include(
      "permalinks" => {
        "copied" => 1,
        "kept destination alias" => 1,
        "reused" => 1,
      },
    )
    get "/help/previous"
    expect(response).to redirect_to(discussion_post.url)
    get "/pub/harbor-manual"
    expect(response).to have_http_status(:ok)
    expect(occupied.reload.user_id).to eq(member.id)
  end
end
