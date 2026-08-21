# frozen_string_literal: true

RSpec.describe "db:migrate" do
  it "compiles the native libvips helper" do
    expect(Rake::Task["db:migrate"].prerequisites).to include("discourse_vips:compile")
  end
end
