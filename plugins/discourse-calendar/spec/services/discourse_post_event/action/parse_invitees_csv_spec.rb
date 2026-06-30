# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::Action::ParseInviteesCsv) do
  subject(:result) { described_class.call(file: file) }

  def csv_file(content)
    tempfile = Tempfile.new(%w[invitees .csv])
    tempfile.write(content)
    tempfile.rewind
    Struct.new(:tempfile).new(tempfile)
  end

  describe ".call" do
    context "when the file has identifiers and attendance values" do
      let(:file) { csv_file("alice,going\nbob,interested\n") }

      it "parses each row into an invitee hash" do
        expect(result).to eq(
          [
            { identifier: "alice", attendance: "going" },
            { identifier: "bob", attendance: "interested" },
          ],
        )
      end
    end

    context "when a row has no attendance value" do
      let(:file) { csv_file("alice\n") }

      it "defaults attendance to going" do
        expect(result).to include(identifier: "alice", attendance: "going")
      end
    end

    context "when a row has a blank identifier" do
      let(:file) { csv_file(",going\nbob,going\n") }

      it "skips the blank row" do
        expect(result).to eq([{ identifier: "bob", attendance: "going" }])
      end
    end

    context "when the file is malformed" do
      let(:file) { csv_file("alice,\"unterminated") }

      it "returns an empty array" do
        expect(result).to be_empty
      end
    end
  end
end
