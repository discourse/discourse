# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Bot do
  subject(:bot) { described_class.allocate }

  fab!(:invoking_user, :user)
  fab!(:upload_owner, :user)
  fab!(:private_group, :group)
  fab!(:private_category) { Fabricate(:private_category, group: private_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category, user: upload_owner) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic, user: upload_owner) }

  let(:secure_upload) do
    upload =
      UploadCreator.new(plugin_file_from_fixtures("1x1.jpg"), "secure-tool-image.jpg").create_for(
        upload_owner.id,
      )
    upload.update!(secure: true, access_control_post_id: private_post.id)
    upload
  end

  before do
    enable_current_plugin
    private_group.add(upload_owner)
  end

  it "does not register tool-returned images hidden from the execution Guardian" do
    context = DiscourseAi::Agents::BotContext.new(user: invoking_user)

    available_images =
      bot.send(
        :register_tool_image_references,
        [secure_upload.short_url],
        context,
        invoking_user.guardian,
      )

    expect(available_images).to be_empty
    expect(context.image_upload_authorized?(secure_upload.id)).to eq(false)
  end

  it "does not register unrelated secure images for the system user" do
    context = DiscourseAi::Agents::BotContext.new(user: Discourse.system_user)

    available_images =
      bot.send(
        :register_tool_image_references,
        [secure_upload.short_url],
        context,
        Discourse.system_user.guardian,
      )

    expect(available_images).to be_empty
    expect(context.image_upload_authorized?(secure_upload.id)).to eq(false)
  end

  it "registers secure images belonging to the system user's current topic" do
    context = DiscourseAi::Agents::BotContext.new(user: Discourse.system_user, topic: private_topic)

    available_images =
      bot.send(
        :register_tool_image_references,
        [secure_upload.short_url],
        context,
        Discourse.system_user.guardian,
      )

    expect(available_images).to contain_exactly(secure_upload.short_url)
    expect(context.image_upload_authorized?(secure_upload.id)).to eq(true)
  end
end
