require 'rails_helper'

RSpec.describe Jobs::ReviseAttachmentLinks do
  fab!(:upload) { Fabricate(:upload) }

  describe '#execute' do
    fab!(:post) do
      Fabricate(:post, raw: <<~RAW)
      Some random text

      ![test](#{upload.short_url})

      <a class="test attachment" href="#{upload.url}">
        test
      </a>

      <a href="#{upload.url}">test</a>
      <a href="#{Discourse.base_url_no_prefix}#{upload.url}">test</a>

      <a href="https://somerandomesite.com#{upload.url}">test</a>
      <a class="attachment" href="https://somerandom.com/url">test</a>
      RAW
    end

    it "should correct the raw" do
      expect do
        described_class.new.execute(post_id: post.id)
      end.to change { post.reload.revisions.count }.by(1)

      expect(post.raw).to eq(<<~RAW.chomp)
      Some random text

      ![test](#{upload.short_url})

      [test|attachment](#{upload.short_url})

      [test](#{upload.short_url})
      [test](#{upload.short_url})

      <a href="https://somerandomesite.com#{upload.url}">test</a>
      <a class="attachment" href="https://somerandom.com/url">test</a>
      RAW

      revision = post.revisions.last

      expect(revision.user_id).to eq(Discourse.system_user.id)

      expect(revision.modifications["edit_reason"][1])
        .to eq(I18n.t("upload.attachments.edit_reason"))
    end

    it "should do nothing if there are no attachment links to revise" do
      post.update!(raw: "this is just some normal text")

      expect do
        described_class.new.execute(post_id: post.id)
      end.to change { post.reload.revisions.count }.by(0)
    end
  end
end
