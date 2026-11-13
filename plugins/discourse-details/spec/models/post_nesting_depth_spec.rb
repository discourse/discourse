# frozen_string_literal: true

RSpec.describe Post do
  before { enable_current_plugin }

  def nested_details(depth)
    source = "Innermost content"
    depth.times { |index| source = "[details=\"Level #{index + 1}\"]\n\n#{source}\n\n[/details]" }
    source
  end

  def validation_errors_for(source)
    post = Fabricate.build(:post, raw: source)
    post.valid?
    post.errors[:base]
  end

  def depth_error(limit)
    I18n.t("details.max_nesting_depth_exceeded", max_depth: limit)
  end

  it "allows unlimited nesting by default" do
    expect(validation_errors_for(nested_details(4))).not_to include(depth_error(0))
  end

  it "allows nesting at the configured limit" do
    SiteSetting.details_max_nesting_depth = 2

    expect(validation_errors_for(nested_details(2))).not_to include(depth_error(2))
  end

  it "rejects nesting beyond the configured limit" do
    SiteSetting.details_max_nesting_depth = 2

    expect(validation_errors_for(nested_details(3))).to include(depth_error(2))
  end

  it "allows sibling details at a depth of one" do
    SiteSetting.details_max_nesting_depth = 1

    source = "#{nested_details(1)}\n\n#{nested_details(1)}"

    expect(validation_errors_for(source)).not_to include(depth_error(1))
  end

  it "does not reject existing posts with unchanged raw content" do
    post = Fabricate(:post, raw: nested_details(3))
    SiteSetting.details_max_nesting_depth = 2

    post.valid?

    expect(post.errors[:base]).not_to include(depth_error(2))
  end
end
