require 'rails_helper'
require 'letter_avatar'

describe LetterAvatar do
  it "can cleanup correctly" do
    path = LetterAvatar.cache_path

    FileUtils.mkdir_p(path + "junk")
    LetterAvatar.generate("test", 100)

    LetterAvatar.cleanup_old

    expect(Dir.entries(File.dirname(path)).length).to eq(3)
  end
end
