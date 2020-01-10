# frozen_string_literal: true

module WebauthnIntegrationHelpers
  ##
  # Usage notes:
  #
  # The valid_security_key_auth_post_data is derived from an actual YubiKey login
  # attempt that is successful. No security risk is posed by this; this YubiKey
  # has only ever been used for local credentials.
  #
  # To make this all work together you need to
  # create a UserSecurityKey for a user using valid_security_key_data,
  # and you override Webauthn::ChallengeGenerator.generate to return
  # a Webauthn::ChallengeGenerator::ChallengeSession object using
  # valid_security_key_challenge_data.
  #
  # This is because the challenge is embedded
  # in the post data's authenticatorData and must match up. See
  # simulate_localhost_webautn_challenge for a real example.
  def valid_security_key_data
    {
      credential_id: "9GiFosW50+s+juyJlyxKEVAsk3gZLo9XWIhX47eC4gHfDsldF3TWR43Tcl/+3gLTL5t1TjpmcbKA2DUV2eKrBw==".freeze,
      public_key: "pQECAyYgASFYIPMGM1OpSuCU5uks+BulAdfVxdlJiYcgGac5Y+LnLXC9Ilgghy0BKvRvptmQdtWz33Jjnf8Y6+HD85XdRiqmo1KMGPE=".freeze
    }
  end

  def valid_security_key_auth_post_data
    {
      signature: "MEYCIQC5xyUQvF4qTPZ2yX7crp/IEs1E/4wqhXgxC1EVAumhfgIhAIC/7w4BVEy+ew6vMYISahtnnIqbqsPZosBeTUSI8Y4j".freeze,
      clientData: "eyJjaGFsbGVuZ2UiOiJOR1UzWW1Zek0yWTBNelkyWkdFM05EVTNZak5qWldVNFpUWTNOakJoTm1NMFlqVTVORFptTlRrd016Vm1ZMlZpTURVd01UZzJOemcxTW1RMSIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6MzAwMCIsInR5cGUiOiJ3ZWJhdXRobi5nZXQifQ==".freeze,
      authenticatorData: "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MBAAAA2Q==".freeze,
      credentialId: valid_security_key_data[:credential_id]
    }
  end

  def valid_security_key_challenge_data
    {
      challenge: "4e7bf33f4366da7457b3cee8e6760a6c4b5946f59035fceb0501867852d5".freeze
    }
  end

  def valid_security_key_create_post_data
    {
      id: "hg7Ojg9H4urf9UlT99T2yr-FQtEGCWnRNdkI5QKEqDxlSjsLHhUcQxeTPelC26cy9XQ_qIg1Nq88PNVDlZvxHA",
      rawId: "hg7Ojg9H4urf9UlT99T2yr+FQtEGCWnRNdkI5QKEqDxlSjsLHhUcQxeTPelC26cy9XQ/qIg1Nq88PNVDlZvxHA==",
      type: "public-key",
      attestation: "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVjESZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2NBAAAAAAAAAAAAAAAAAAAAAAAAAAAAQIYOzo4PR+Lq3/VJU/fU9sq/hULRBglp0TXZCOUChKg8ZUo7Cx4VHEMXkz3pQtunMvV0P6iINTavPDzVQ5Wb8RylAQIDJiABIVggJI3i7Svv1+Hu8pGYIQ6XEIeWHxjr+qKVXPmXSQswGysiWCDs0ZRoPXkajl+Mpvc16BPVFrKRxl06V+XTKdKffiMzZQ==",
      clientData: "eyJjaGFsbGVuZ2UiOiJOR1UzWW1Zek0yWTBNelkyWkdFM05EVTNZak5qWldVNFpUWTNOakJoTm1NMFlqVTVORFptTlRrd016Vm1ZMlZpTURVd01UZzJOemcxTW1RMSIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6MzAwMCIsInR5cGUiOiJ3ZWJhdXRobi5jcmVhdGUifQ==",
      name: "My Security Key"
    }
  end

  # all of the valid security key data is sourced from a localhost
  # login, if this is not set the specs for webauthn WILL NOT WORK
  def stub_as_dev_localhost
    Discourse.stubs(:current_hostname).returns('localhost')
    Discourse.stubs(:base_url).returns('http://localhost:3000')
  end

  def simulate_localhost_webauthn_challenge
    stub_as_dev_localhost
    Webauthn::ChallengeGenerator.stubs(:generate).returns(
      Webauthn::ChallengeGenerator::ChallengeSession.new(
        challenge: valid_security_key_challenge_data[:challenge],
        rp_id: Discourse.current_hostname
      )
    )
  end
end
