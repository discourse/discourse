# frozen_string_literal: true

RSpec.describe "Composer pointer resize oracle" do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(user) }

  it "lets the user resize the composer by dragging its separator" do
    topic_page.visit_topic_and_open_composer(topic)
    expect(composer).to be_opened
    initial_height = composer.height

    composer.drag_resize_by(50)

    expect(composer).to have_height(initial_height + 50)
  end
end
