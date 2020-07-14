# frozen_string_literal: true

require "rails_helper"

describe "about/index.html.erb" do
  let(:admin1) { Fabricate(:admin) }
  let(:admin2) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }

  context "crawler view" do
    before do
      def controller.use_crawler_layout?
        true
      end
      admin1
      admin2
    end
    it "renders admin user page links" do
      @about = About.new(user)

      render

      expect(rendered).to match("/u/#{admin1.username_lower}")
      expect(rendered).to match(admin2.small_avatar_url)
    end
  end

end
