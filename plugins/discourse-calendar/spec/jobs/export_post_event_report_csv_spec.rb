# frozen_string_literal: true

describe Jobs::ExportCsvFile do
  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "#execute" do
    context "when the requesting user is admin" do
      let(:user) { Fabricate(:user, admin: true) }
      let(:user_1) { Fabricate(:user) }
      let(:user_2) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }
      let(:post1) { Fabricate(:post, topic: topic) }
      let(:post_event) { Fabricate(:event, post: post1) }

      context "when the event exists" do
        context "when the event has invitees" do
          before do
            post_event.create_invitees([{ user_id: user_1.id, status: nil }])
            post_event.create_invitees([{ user_id: user_2.id, status: 2 }])
          end

          context "when the user requesting the upload is admin" do
            it "generates the upload and notify the user" do
              begin
                expect do
                  Jobs::ExportCsvFile.new.execute(
                    user_id: user.id,
                    entity: "post_event",
                    args: {
                      id: post_event.id,
                    },
                  )
                end.to change { Upload.count }.by(1)

                system_message = user.topics_allowed.last

                expect(system_message.title).to eq(
                  I18n.t(
                    "system_messages.csv_export_succeeded.subject_template",
                    export_title: "Post Event",
                  ),
                )

                upload = system_message.first_post.uploads.first

                expect(system_message.first_post.raw).to eq(
                  I18n.t(
                    "system_messages.csv_export_succeeded.text_body_template",
                    download_link:
                      "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.filesize} Bytes)",
                  ).chomp,
                )

                expect(system_message.id).to eq(UserExport.last.topic_id)
                expect(system_message.closed).to eq(true)

                files = []
                Zip::File.open(Discourse.store.path_for(upload)) do |zip_file|
                  zip_file.each do |entry|
                    files << entry.name

                    input_stream = entry.get_input_stream
                    parsed_csv = CSV.parse(input_stream.read)

                    expect(parsed_csv[0]).to eq(
                      %w[username status first_answered_at last_updated_at],
                    )
                    invitee_1 = post_event.invitees.find_by(user_id: user_1.id)
                    expect(parsed_csv[1]).to eq(
                      [user_1.username, nil, invitee_1.created_at.to_s, invitee_1.updated_at.to_s],
                    )
                    invitee_2 = post_event.invitees.find_by(user_id: user_2.id)
                    expect(parsed_csv[2]).to eq(
                      [
                        user_2.username,
                        "not_going",
                        invitee_2.created_at.to_s,
                        invitee_2.updated_at.to_s,
                      ],
                    )
                  end
                end

                expect(files.size).to eq(1)
              ensure
                user.uploads.each(&:destroy!)
              end
            end
          end
        end
      end
    end

    context "when the requesting user is not admin" do
      let(:user) { Fabricate(:user) }
      let(:requesting_user) { Fabricate(:user, admin: false) }
      let(:user_1) { Fabricate(:user) }
      let(:user_2) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }
      let(:post1) { Fabricate(:post, topic: topic) }
      let(:post_event) { Fabricate(:event, post: post1) }

      it "doesn’t generate the upload" do
        expect do
          Jobs::ExportCsvFile.new.execute(
            user_id: requesting_user.id,
            entity: "post_event",
            args: {
              id: post_event.id,
            },
          )
        end.to raise_error Discourse::InvalidAccess
      end
    end

    context "when the requesting user is not admin but can act on this event" do
      let(:user) { Fabricate(:user, admin: false, refresh_auto_groups: true) }
      let(:user_1) { Fabricate(:user) }
      let(:user_2) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }
      let(:post1) { Fabricate(:post, topic: topic, user: user) }
      let(:post_event) { Fabricate(:event, post: post1) }
      let(:group_1) do
        Fabricate(:group).tap do |g|
          g.add(user)
          g.save!
        end
      end

      before { SiteSetting.discourse_post_event_allowed_on_groups = group_1.id }

      it "generates the upload" do
        begin
          expect do
            Jobs::ExportCsvFile.new.execute(
              user_id: user.id,
              entity: "post_event",
              args: {
                id: post_event.id,
              },
            )
          end.to change { Upload.count }.by(1)
        ensure
          user.uploads.each(&:destroy!)
        end
      end
    end
  end
end
