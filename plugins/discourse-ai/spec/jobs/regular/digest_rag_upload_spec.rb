# frozen_string_literal: true

describe Jobs::DigestRagUpload do
  subject(:job) { described_class.new }

  fab!(:agent, :ai_agent)
  fab!(:upload) { Fabricate(:upload, extension: "txt") }
  fab!(:image_upload) { Fabricate(:upload, extension: "png") }
  let(:document_file) { StringIO.new("some text" * 200) }

  fab!(:cloudflare_embedding_def)
  let(:expected_embedding) { [0.0038493] * cloudflare_embedding_def.dimensions }

  let(:document_with_metadata) { plugin_file_from_fixtures("doc_with_metadata.txt", "rag") }

  let(:parsed_document_with_metadata) do
    plugin_file_from_fixtures("parsed_doc_with_metadata.txt", "rag")
  end

  let(:upload_with_metadata) do
    UploadCreator.new(document_with_metadata, "document.txt").create_for(Discourse.system_user.id)
  end

  before do
    enable_current_plugin

    SiteSetting.ai_embeddings_selected_model = cloudflare_embedding_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.authorized_extensions = "txt"

    WebMock.stub_request(:post, cloudflare_embedding_def.url).to_return(
      status: 200,
      body: JSON.dump(expected_embedding),
    )
  end

  describe "#execute" do
    context "when processing an image upload" do
      it "rejects the indexing if the site setting is not enabled" do
        SiteSetting.ai_rag_images_enabled = false

        expect {
          described_class.new.execute(
            upload_id: image_upload.id,
            target_id: agent.id,
            target_type: agent.class.to_s,
          )
        }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when processing a PDF upload" do
      let(:pdf) { plugin_file_from_fixtures("2-page.pdf", "rag") }

      it "indexes multilingual text extracted from the PDF" do
        SiteSetting.authorized_extensions = "txt|pdf"
        pdf_upload = UploadCreator.new(pdf, "2-page.pdf").create_for(Discourse.system_user.id)

        job.execute(upload_id: pdf_upload.id, target_id: agent.id, target_type: agent.class.to_s)

        indexed_content =
          RagDocumentFragment
            .where(upload: pdf_upload, target: agent)
            .order(:fragment_number)
            .pluck(:fragment)
            .join("\n")

        expect(indexed_content).to include("| 猫 | cat | 貓 |", "| 犬 | dog | 狗 |")
      end
    end

    context "when processing an upload containing metadata" do
      it "correctly splits on metadata boundary" do
        # be explicit here about chunking strategy
        agent.update!(rag_chunk_tokens: 100, rag_chunk_overlap_tokens: 10)

        described_class.new.execute(
          upload_id: upload_with_metadata.id,
          target_id: agent.id,
          target_type: agent.class.to_s,
        )

        parsed = +""
        first = true
        RagDocumentFragment
          .where(upload: upload_with_metadata)
          .order(:fragment_number)
          .each do |fragment|
            parsed << "\n\n" if !first
            parsed << "metadata: #{fragment.metadata}\n"
            parsed << "number: #{fragment.fragment_number}\n"
            parsed << fragment.fragment
            first = false
          end

        # to rebuild parsed
        #File.write("/tmp/testing", parsed)

        expect(parsed).to eq(parsed_document_with_metadata.read.delete_suffix("\n"))
      end
    end

    context "when processing an upload for the first time" do
      before { File.expects(:open).returns(document_file) }

      it "splits an upload into chunks" do
        job.execute(upload_id: upload.id, target_id: agent.id, target_type: agent.class.to_s)

        created_fragment = RagDocumentFragment.last

        expect(created_fragment).to be_present
        expect(created_fragment.fragment).to be_present
        expect(created_fragment.fragment_number).to eq(2)
      end

      it "queue jobs to generate embeddings for each fragment" do
        expect {
          job.execute(upload_id: upload.id, target_id: agent.id, target_type: agent.class.to_s)
        }.to change(Jobs::GenerateRagEmbeddings.jobs, :size).by(1)
      end

      context "when UTF-8 content crosses a read boundary" do
        let(:multilingual_row) { "| 雷顎大剣ドネルヘレヴ | Donnerzahn | 兵器雷顎大劍 |\n" }
        let(:document_file) do
          read_size = agent.rag_chunk_tokens * 10
          StringIO.new((("a" * (read_size - 1)) + "猫\n" + multilingual_row).b)
        end

        it "preserves multilingual content across read boundaries" do
          SiteSetting.authorized_extensions = "txt|md"
          markdown_upload = Fabricate(:upload, extension: "md", original_filename: "glossary.md")
          job.execute(
            upload_id: markdown_upload.id,
            target_id: agent.id,
            target_type: agent.class.to_s,
          )

          indexed_content =
            RagDocumentFragment
              .where(upload: markdown_upload, target: agent)
              .order(:fragment_number)
              .pluck(:fragment)
              .join("\n")

          expect(indexed_content).to include("猫", multilingual_row.strip)
        end
      end

      context "when the document contains a UTF-8 byte order mark" do
        let(:document_file) { StringIO.new("\xEF\xBB\xBF猫".b) }

        it "removes the byte order mark" do
          job.execute(upload_id: upload.id, target_id: agent.id, target_type: agent.class.to_s)

          indexed_content =
            RagDocumentFragment
              .where(upload:, target: agent)
              .order(:fragment_number)
              .pick(:fragment)

          expect(indexed_content).to eq("猫")
        end
      end

      context "when a UTF-8 text document contains an invalid byte" do
        let(:document_file) { StringIO.new("before 猫 \xFF after 犬\n".b) }

        it "removes the invalid byte and preserves the surrounding text" do
          job.execute(upload_id: upload.id, target_id: agent.id, target_type: agent.class.to_s)

          indexed_content =
            RagDocumentFragment
              .where(upload:, target: agent)
              .order(:fragment_number)
              .pick(:fragment)

          expect(indexed_content).to eq("before 猫  after 犬")
        end
      end

      context "when the document produces a blank trailing chunk" do
        let(:document_file) do
          StringIO.new(
            "[[metadata {\"source_url\":\"https://example.com\"}]]\n#{"some text " * 200}\n",
          )
        end

        it "only creates fragments containing text" do
          job.execute(upload_id: upload.id, target_id: agent.id, target_type: agent.class.to_s)

          fragments = RagDocumentFragment.where(upload:, target: agent).pluck(:fragment)

          expect(fragments).to all(be_present)
        end
      end
    end

    it "doesn't generate new fragments if we already processed the upload" do
      Fabricate(:rag_document_fragment, upload: upload, target: agent)

      previous_count = RagDocumentFragment.where(upload: upload, target: agent).count

      job.execute(upload_id: upload.id, target_id: agent.id, target_type: agent.class.to_s)
      updated_count = RagDocumentFragment.where(upload: upload, target: agent).count

      expect(updated_count).to eq(previous_count)
    end
  end
end
