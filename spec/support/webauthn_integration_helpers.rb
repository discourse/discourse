# frozen_string_literal: true

module DiscourseWebauthnIntegrationHelpers
  ##
  # Usage notes:
  #
  # The valid_security_key_auth_post_data is derived from an actual YubiKey login
  # attempt that is successful. No security risk is posed by this; this YubiKey
  # has only ever been used for local credentials.
  #
  # To make this all work together you need to
  # create a UserSecurityKey for a user using valid_security_key_data,
  # and you override DiscourseWebauthn::ChallengeGenerator.generate to return
  # a DiscourseWebauthn::ChallengeGenerator::ChallengeSession object using
  # valid_security_key_challenge_data.
  #
  # This is because the challenge is embedded
  # in the post data's authenticatorData and must match up. See
  # simulate_localhost_webauthn_challenge for a real example.

  # All of the valid security key data is sourced from a localhost
  # login (with origin http://localhost:3000).

  def valid_security_key_data
    {
      credential_id:
        "9GiFosW50+s+juyJlyxKEVAsk3gZLo9XWIhX47eC4gHfDsldF3TWR43Tcl/+3gLTL5t1TjpmcbKA2DUV2eKrBw==",
      public_key:
        "pQECAyYgASFYIPMGM1OpSuCU5uks+BulAdfVxdlJiYcgGac5Y+LnLXC9Ilgghy0BKvRvptmQdtWz33Jjnf8Y6+HD85XdRiqmo1KMGPE=",
    }
  end

  def valid_security_key_auth_post_data
    {
      signature:
        "MEYCIQC5xyUQvF4qTPZ2yX7crp/IEs1E/4wqhXgxC1EVAumhfgIhAIC/7w4BVEy+ew6vMYISahtnnIqbqsPZosBeTUSI8Y4j",
      clientData:
        "eyJjaGFsbGVuZ2UiOiJOR1UzWW1Zek0yWTBNelkyWkdFM05EVTNZak5qWldVNFpUWTNOakJoTm1NMFlqVTVORFptTlRrd016Vm1ZMlZpTURVd01UZzJOemcxTW1RMSIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6MzAwMCIsInR5cGUiOiJ3ZWJhdXRobi5nZXQifQ==",
      authenticatorData: "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MBAAAA2Q==",
      credentialId: valid_security_key_data[:credential_id],
    }
  end

  def valid_security_key_challenge_data
    { challenge: "4e7bf33f4366da7457b3cee8e6760a6c4b5946f59035fceb0501867852d5" }
  end

  def valid_security_key_create_post_data
    {
      id: "hg7Ojg9H4urf9UlT99T2yr-FQtEGCWnRNdkI5QKEqDxlSjsLHhUcQxeTPelC26cy9XQ_qIg1Nq88PNVDlZvxHA",
      rawId:
        "hg7Ojg9H4urf9UlT99T2yr+FQtEGCWnRNdkI5QKEqDxlSjsLHhUcQxeTPelC26cy9XQ/qIg1Nq88PNVDlZvxHA==",
      type: "public-key",
      attestation:
        "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVjESZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2NBAAAAAAAAAAAAAAAAAAAAAAAAAAAAQIYOzo4PR+Lq3/VJU/fU9sq/hULRBglp0TXZCOUChKg8ZUo7Cx4VHEMXkz3pQtunMvV0P6iINTavPDzVQ5Wb8RylAQIDJiABIVggJI3i7Svv1+Hu8pGYIQ6XEIeWHxjr+qKVXPmXSQswGysiWCDs0ZRoPXkajl+Mpvc16BPVFrKRxl06V+XTKdKffiMzZQ==",
      clientData:
        "eyJjaGFsbGVuZ2UiOiJOR1UzWW1Zek0yWTBNelkyWkdFM05EVTNZak5qWldVNFpUWTNOakJoTm1NMFlqVTVORFptTlRrd016Vm1ZMlZpTURVd01UZzJOemcxTW1RMSIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6MzAwMCIsInR5cGUiOiJ3ZWJhdXRobi5jcmVhdGUifQ==",
      name: "My Security Key",
    }
  end

  def simulate_localhost_webauthn_challenge
    DiscourseWebauthn.stubs(:challenge).returns(valid_security_key_challenge_data[:challenge])
  end

  # Passkey data sourced from a key generated in a local browser
  # with webauthn.create that includes the user verification flag on localhost:3000
  # usin puts statements in the passkeys session controllers
  def valid_passkey_challenge
    "66b47014ef72937d8320ed893dc797e8a9a6d5098b89b185ca3d439b3656"
  end

  def passkey_client_data_param(type)
    {
      type: type,
      challenge: Base64.strict_encode64(valid_passkey_challenge),
      origin: "http://localhost:3000",
      crossOrigin: false,
    }
  end

  def valid_passkey_auth_data
    {
      clientData: Base64.strict_encode64(passkey_client_data_param("webauthn.get").to_json),
      credentialId: "JFeriwVn1elZk7N8nwSC4magQ8zM1XIUxRZB9Pm7VDM=",
      authenticatorData: "SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MFAAAAAA==",
      signature:
        "MEUCIG5AFaw2Nfy69hHjeRLqm3LzQRMFb+TRbUAz19WJymegAiEAyEEyGdAMB2/NBwRCHM47IwtjKWCLEtabAX2BaK6fD8g=",
    }
  end

  def valid_passkey_data
    {
      credential_id: "JFeriwVn1elZk7N8nwSC4magQ8zM1XIUxRZB9Pm7VDM=",
      public_key:
        "pQECAyYgASFYILjOiAHAwNrXkCk/tmyYRiE87QyV/15wUvhcXhr1JfwtIlggClQywgQvSxTsqV/FSK0cNHTTmuwfzzREqE6eLDmPxmI=",
    }
  end

  def simulate_localhost_passkey_challenge
    DiscourseWebauthn.stubs(:challenge).returns(valid_passkey_challenge)
  end
end
