# frozen_string_literal: true

RSpec.describe "Inserting templates in the chat composer", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:templates_category, :category)
  fab!(:template_simple) { Fabricate(:template_item, category: templates_category) }
  fab!(:template_variables) do
    Fabricate(
      :template_item,
      content: templates_allowed_variables.map { |v| "#{v} = %{#{v}}" }.join("\n"),
      category: templates_category,
    )
  end

  fab!(:channel_1, :chat_channel)
  fab!(:message_1) do
    Fabricate(:chat_message, user: current_user, chat_channel: channel_1, use_service: true)
  end
  fab!(:message_2) do
    Fabricate(:chat_message, user: other_user, in_reply_to: message_1, use_service: true)
  end
  fab!(:message_3) do
    Fabricate(:chat_message, user: other_user, chat_channel: channel_1, use_service: true)
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:insert_template_modal) { PageObjects::Modals::DTemplatesInsertTemplate.new }

  let(:expected_values_channel) do
    {
      my_username: "#{current_user.username}",
      my_name: "#{current_user.name}",
      chat_channel_name: "#{channel_1.name}",
      chat_channel_url: "/chat/c/#{channel_1.slug}/#{channel_1.id}",
      context_title: "#{channel_1.name}",
      context_url: "/chat/c/#{channel_1.slug}/#{channel_1.id}",
    }
  end
  let(:reply_values) do
    { reply_to_username: "#{current_user.username}", reply_to_name: "#{current_user.name}" }
  end
  let(:template_variables_no_reply_expected_content_channel) do
    templates_allowed_variables.map { |v| "#{v} = #{expected_values_channel[v.to_sym]}" }.join("\n")
  end
  let(:template_variables_replying_expected_content_channel) do
    templates_allowed_variables
      .map { |v| "#{v} = #{expected_values_channel[v.to_sym] || reply_values[v.to_sym]}" }
      .join("\n")
  end

  let(:expected_values_thread) do
    {
      my_username: "#{current_user.username}",
      my_name: "#{current_user.name}",
      chat_channel_name: "#{channel_1.name}",
      chat_channel_url: "/chat/c/#{channel_1.slug}/#{channel_1.id}",
      chat_thread_name: "#{message_2.thread.title}",
      chat_thread_url: "/chat/c/#{channel_1.slug}/#{channel_1.id}/t/#{message_2.thread.id}",
      context_title: "#{message_2.thread.title}",
      context_url: "/chat/c/#{channel_1.slug}/#{channel_1.id}/t/#{message_2.thread.id}",
      reply_to_username: "#{current_user.username}",
      reply_to_name: "#{current_user.name}",
    }
  end
  let(:template_variables_expected_content_thread) do
    templates_allowed_variables.map { |v| "#{v} = #{expected_values_thread[v.to_sym]}" }.join("\n")
  end

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    channel_1.add(other_user)

    SiteSetting.discourse_templates_enabled = true
    SiteSetting.discourse_templates_categories = templates_category.id.to_s

    sign_in(current_user)
  end

  context "when typing a message in the channel composer" do
    context "when the template is inserted using the action button" do
      it "inserting a template works" do
        chat_page.visit_channel(channel_1)
        channel_page.open_action_menu
        channel_page.click_action_button("d-templates-chat-insert-template-btn")

        insert_template_modal.open?
        insert_template_modal.select_template(template_simple.id)

        expect(channel_page.composer.value.strip).to eq(template_simple.first_post.raw.strip)
      end

      it "the variables are replaced with correct values" do
        chat_page.visit_channel(channel_1)
        channel_page.open_action_menu
        channel_page.click_action_button("d-templates-chat-insert-template-btn")

        insert_template_modal.open?
        insert_template_modal.select_template(template_variables.id)

        expect(channel_page.composer.value.strip).to eq(
          template_variables_no_reply_expected_content_channel.strip,
        )
      end

      it "the variables are replaced with correct values when replying a message" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(message_1)

        channel_page.open_action_menu
        channel_page.click_action_button("d-templates-chat-insert-template-btn")

        insert_template_modal.open?
        insert_template_modal.select_template(template_variables.id)

        expect(channel_page.composer.value.strip).to eq(
          template_variables_replying_expected_content_channel.strip,
        )
      end
    end

    context "when the template is inserted using keyboard shortcut" do
      it "inserting a template works" do
        chat_page.visit_channel(channel_1)

        channel_page.composer.focus # ensure the focus is the textarea
        expect(channel_page.composer).to be_focused

        insert_template_modal.open_with_keyboard_shortcut
        insert_template_modal.open?
        insert_template_modal.select_template(template_simple.id)

        expect(channel_page.composer.value.strip).to eq(template_simple.first_post.raw.strip)
      end

      it "the variables are replaced with correct values" do
        chat_page.visit_channel(channel_1)

        channel_page.composer.focus # ensure the focus is the textarea
        expect(channel_page.composer).to be_focused

        insert_template_modal.open_with_keyboard_shortcut
        insert_template_modal.open?
        insert_template_modal.select_template(template_variables.id)

        expect(channel_page.composer.value.strip).to eq(
          template_variables_no_reply_expected_content_channel.strip,
        )
      end

      it "the variables are replaced with correct values when replying a message" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(message_1)

        channel_page.composer.focus # ensure the focus is the textarea
        expect(channel_page.composer).to be_focused

        insert_template_modal.open_with_keyboard_shortcut
        insert_template_modal.open?
        insert_template_modal.select_template(template_variables.id)

        expect(channel_page.composer.value.strip).to eq(
          template_variables_replying_expected_content_channel.strip,
        )
      end
    end
  end

  context "when typing a message in the thread composer" do
    before do
      channel_1.threading_enabled = true
      channel_1.save!

      message_2.thread.title = "New thread title"
      message_2.thread.save!
    end

    context "when the template is inserted using the action button" do
      it "inserting a template works" do
        chat_page.visit_thread(message_2.thread)

        # thread page does not define the methods open_action_menu and click_action_button
        thread_page.composer.component.find(".chat-composer-dropdown__trigger-btn").click
        find(".chat-composer-dropdown__action-btn.d-templates-chat-insert-template-btn").click

        insert_template_modal.open?
        insert_template_modal.select_template(template_simple.id)

        expect(thread_page.composer.value.strip).to eq(template_simple.first_post.raw.strip)
      end

      it "the variables are replaced with correct values" do
        chat_page.visit_thread(message_2.thread)

        # thread page does not define the methods open_action_menu and click_action_button
        thread_page.composer.component.find(".chat-composer-dropdown__trigger-btn").click
        find(".chat-composer-dropdown__action-btn.d-templates-chat-insert-template-btn").click

        insert_template_modal.open?
        insert_template_modal.select_template(template_variables.id)

        expect(thread_page.composer.value.strip).to eq(
          template_variables_expected_content_thread.strip,
        )
      end
    end

    context "when the template is inserted using keyboard shortcut" do
      it "inserting a template works" do
        chat_page.visit_thread(message_2.thread)

        thread_page.composer.focus # ensure the focus is the textarea
        expect(thread_page.composer).to be_focused

        insert_template_modal.open_with_keyboard_shortcut
        insert_template_modal.open?
        insert_template_modal.select_template(template_simple.id)

        expect(thread_page.composer.value.strip).to eq(template_simple.first_post.raw.strip)
      end

      it "the variables are replaced with correct values" do
        chat_page.visit_thread(message_2.thread)

        thread_page.composer.focus # ensure the focus is the textarea
        expect(thread_page.composer).to be_focused

        insert_template_modal.open_with_keyboard_shortcut
        insert_template_modal.open?
        insert_template_modal.select_template(template_variables.id)

        expect(thread_page.composer.value.strip).to eq(
          template_variables_expected_content_thread.strip,
        )
      end
    end
  end
end
