# frozen_string_literal: true

describe UserCardSerializer do
  let(:user) { Fabricate(:user) }
  let(:serializer) { described_class.new(user, scope: Guardian.new, root: false) }
  let(:json) { serializer.as_json }

  it "accepted_answers serializes number of accepted answers" do
    expect(serializer.as_json[:accepted_answers]).to eq(0)

    post1 = Fabricate(:post, user: user)
    DiscourseSolved.accept_answer!(post1, Discourse.system_user)
    post1.topic.reload
    expect(serializer.as_json[:accepted_answers]).to eq(1)

    post2 = Fabricate(:post, user: user)
    DiscourseSolved.accept_answer!(post2, Discourse.system_user)
    expect(serializer.as_json[:accepted_answers]).to eq(2)

    post3 = Fabricate(:post, user: user)
    DiscourseSolved.accept_answer!(post3, Discourse.system_user)
    expect(serializer.as_json[:accepted_answers]).to eq(3)

    DiscourseSolved.unaccept_answer!(post1)
    expect(serializer.as_json[:accepted_answers]).to eq(2)

    post2.topic.trash!(Discourse.system_user)
    expect(serializer.as_json[:accepted_answers]).to eq(1)

    post3.topic.convert_to_private_message(Discourse.system_user)
    expect(serializer.as_json[:accepted_answers]).to eq(0)
  end
end
