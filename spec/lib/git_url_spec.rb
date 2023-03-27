# frozen_string_literal: true

RSpec.describe GitUrl do
  it "handles the discourse github repo by ssh" do
    expect(GitUrl.normalize("git@github.com:discourse/discourse.git")).to eq(
      "ssh://git@github.com/discourse/discourse.git",
    )
  end

  it "handles the discourse github repo by https" do
    expect(GitUrl.normalize("https://github.com/discourse/discourse.git")).to eq(
      "https://github.com/discourse/discourse.git",
    )
  end
end
