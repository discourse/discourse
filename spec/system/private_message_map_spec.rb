# frozen_string_literal: true

describe "Topic Map - Private Message", type: :system do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:last_post_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) do
    Fabricate(
      :private_message_topic,
      created_at: 1.day.ago,
      user: user,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: other_user),
        Fabricate.build(:topic_allowed_user, user: last_post_user),
      ],
    )
  end
  fab!(:original_post) { Fabricate(:post, topic: topic, user: user, created_at: 1.day.ago) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_map) { PageObjects::Components::TopicMap.new }
  let(:private_message_map) { PageObjects::Components::PrivateMessageMap.new }
  let(:private_message_invite_modal) { PageObjects::Modals::PrivateMessageInvite.new }
  let(:private_message_remove_participant_modal) do
    PageObjects::Modals::PrivateMessageRemoveParticipant.new
  end

  def avatar_url(user, size)
    URI(user.avatar_template_url.gsub("{size}", size.to_s)).path
  end

  it "updates the various topic stats, avatars" do
    freeze_time
    sign_in(user)
    topic_page.visit_topic(topic)

    # topic map appears after OP
    expect(topic_page).to have_topic_map

    # created avatar display
    expect(topic_map.created_details).to have_selector("img[src=\"#{avatar_url(user, 24)}\"]")
    expect(topic_map.created_relative_date).to eq "1d"

    # replies, user count
    expect {
      Fabricate(:post, topic: topic, user: user, created_at: 1.day.ago)
      sign_in(last_post_user)
      topic_page.visit_topic_and_open_composer(topic)
      topic_page.send_reply("this is a cool-cat post") # fabricating posts doesn't update the last post details
      topic_page.visit_topic(topic)
    }.to change(topic_map, :replies_count).by(2).and change(topic_map, :users_count).by(1)

    #last reply avatar display
    expect(topic_map.last_reply_details).to have_selector(
      "img[src=\"#{avatar_url(last_post_user, 24)}\"]",
    )
    expect(topic_map.last_reply_relative_date).to eq "1m"

    # avatars details with post counts
    2.times { Fabricate(:post, topic: topic) }
    Fabricate(:post, user: user, topic: topic)
    Fabricate(:post, user: last_post_user, topic: topic)
    page.refresh
    avatars = topic_map.avatars_details
    expect(avatars.length).to eq 3 # max no. of avatars in a collapsed map
    expect(avatars[0]).to have_selector("img[src=\"#{avatar_url(user, 48)}\"]")
    expect(avatars[0].find(".post-count").text).to eq "3"
    expect(avatars[1]).to have_selector("img[src=\"#{avatar_url(last_post_user, 48)}\"]")
    expect(avatars[1].find(".post-count").text).to eq "2"
    expect(avatars[2]).to have_no_css(".post-count")

    topic_map.expand
    expect(topic_map).to have_no_avatars_details_in_map
    expect(topic_map.expanded_map_avatars_details.length).to eq 4

    # views count
    # TODO (martin) Investigate flakiness
    # sign_in(other_user)
    # topic_page.visit_topic(topic)
    # try_until_success { expect(TopicViewItem.count).to eq(2) }
    # page.refresh
    # expect(topic_map.views_count).to eq(2)

    # likes count
    expect(topic_map).to have_no_likes
    topic_page.click_like_reaction_for(original_post)
    expect(topic_map.likes_count).to eq 1
  end

  it "has private message map that shows correct participants and allows editing of participant invites" do
    freeze_time
    sign_in(user)
    topic_page.visit_topic(topic)

    expect(topic_page).to have_private_message_map

    # participants' links and avatars
    private_message_map
      .participants_details
      .zip([user, other_user, last_post_user]) do |details, usr|
        expect(details).to have_link(usr.username, href: "/u/#{usr.username}")
        expect(details.find(".trigger-user-card")).to have_selector(
          "img[src=\"#{avatar_url(usr, 24)}\"]",
        )
      end

    # toggle ability to edit participants
    private_message_map.toggle_edit_participants_button
    expect(private_message_map).to have_add_participants_button
    private_message_map.toggle_edit_participants_button
    expect(private_message_map).to have_no_add_participants_button

    # removing participants
    private_message_map.toggle_edit_participants_button
    private_message_map.participants_details.each do |details|
      expect(details).to have_css(".remove-invited .d-icon-times")
    end
    private_message_map.click_remove_participant_button(last_post_user)
    expect(private_message_remove_participant_modal).to be_open
    expect(private_message_remove_participant_modal.body).to have_text(
      I18n.t("js.private_message_info.remove_allowed_user", name: last_post_user.username),
    )
    private_message_remove_participant_modal.cancel
    expect(private_message_remove_participant_modal).to be_closed
    expect(private_message_map).to have_participant_details_for(last_post_user)
    private_message_map.click_remove_participant_button(last_post_user)
    expect(private_message_remove_participant_modal).to be_open
    private_message_remove_participant_modal.confirm_removal
    expect(private_message_map).to have_no_participant_details_for(last_post_user)

    # adding participants
    expect {
      expect(private_message_map).to have_add_participants_button
      private_message_map.click_add_participants_button
      expect(private_message_invite_modal).to be_open
      private_message_invite_modal.select_invitee(other_user)
      private_message_invite_modal.click_primary_button
      expect(private_message_invite_modal).to have_invitee_already_exists_error
      private_message_invite_modal.select_invitee(last_post_user)
      private_message_invite_modal.click_primary_button #sends invite
      expect(private_message_invite_modal).to have_successful_invite_message
      private_message_invite_modal.click_primary_button #closes modal
      expect(private_message_invite_modal).to be_closed
    }.to change(private_message_map, :participants_count).by 1
  end
end
