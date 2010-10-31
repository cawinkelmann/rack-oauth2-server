require File.dirname(__FILE__) + "/config"


# 3.  Obtaining End-User Authorization
class AuthorizationTest < Test::Unit::TestCase
  module Helpers

    def should_redirect_with_error(error)
      should "respond with status code 302 (Found)" do
        assert_equal 302, last_response.status
      end
      should "redirect back to redirect_uri" do
        assert_equal URI.parse(last_response["Location"]).host, "uberclient.dot"
      end
      should "redirect with error code #{error}" do
        assert_equal error.to_s, Rack::Utils.parse_query(URI.parse(last_response["Location"]).query)["error"]
      end
      should "redirect with state parameter" do
        assert_equal "bring this back", Rack::Utils.parse_query(URI.parse(last_response["Location"]).query)["state"]
      end
    end

    def should_ask_user_for_authorization(&block)
      should "ask user for authorization" do
        assert SimpleApp.end_user_sees
      end
      should "should inform user about client" do
        assert_equal "UberClient", SimpleApp.end_user_sees[:client]
      end
      should "should inform user about scope" do
        assert_equal %w{read write}, SimpleApp.end_user_sees[:scope]
      end
    end

  end
  extend Helpers

  def setup
    super
    @params = { :redirect_uri=>client.redirect_uri, :client_id=>client.id, :client_secret=>client.secret, :response_type=>"code",
                :scope=>"read write", :state=>"bring this back" }
  end

  def request_authorization(changes = nil)
    get "/oauth/authorize?" + Rack::Utils.build_query(@params.merge(changes || {}))
  end


  # Checks before we request user for authorization.
  # 3.2.  Error Response

  context "no redirect URI" do
    setup { request_authorization :redirect_uri=>nil }
    should "return status 400" do
      assert_equal 400, last_response.status
    end
  end

  context "invalid redirect URI" do
    setup { request_authorization :redirect_uri=>"http:not-valid" }
    should "return status 400" do
      assert_equal 400, last_response.status
    end
  end

  context "no client ID" do
    setup { request_authorization :client_id=>nil }
    should_redirect_with_error :invalid_client
  end

  context "invalid client ID" do
    setup { request_authorization :client_id=>"foobar" }
    should_redirect_with_error :invalid_client
  end

  context "client ID but no such client" do
    setup { request_authorization :client_id=>"4cc7bc483321e814b8000000" }
    should_redirect_with_error :invalid_client
  end

  context "no client secret" do
    setup { request_authorization :client_secret=>nil }
    should_redirect_with_error :invalid_client
  end

  context "wrong client secret" do
    setup { request_authorization :client_secret=>"plain wrong" }
    should_redirect_with_error :invalid_client
  end

  context "mismatched redirect URI" do
    setup { request_authorization :redirect_uri=>"http://uberclient.dot/oz" }
    should_redirect_with_error :redirect_uri_mismatch
  end

  context "revoked client" do
    setup do
      client.revoke!
      request_authorization
    end
    should_redirect_with_error :invalid_client
  end

  context "no response type" do
    setup { request_authorization :response_type=>nil }
    should_redirect_with_error :unsupported_response_type
  end

  context "unknown response type" do
    setup { request_authorization :response_type=>"foobar" }
    should_redirect_with_error :unsupported_response_type
  end

  context "unsupported scope" do
    setup do
      request_authorization :scope=>"read write math"
    end
    should_redirect_with_error :invalid_scope
  end


  # 3.1.  Authorization Response
  
  context "expecting authorization code" do
    setup do
      @params[:response_type] = "code"
      request_authorization
    end
    should_ask_user_for_authorization

    context "and granted" do
      setup { post "/oauth/grant" }

      should "redirect" do
        assert_equal 302, last_response.status
      end
      should "redirect back to client" do
        uri = URI.parse(last_response["Location"])
        assert_equal "uberclient.dot", uri.host
        assert_equal "/callback", uri.path
      end

      context "redirect URL query parameters" do
        setup { @return = Rack::Utils.parse_query(URI.parse(last_response["Location"]).query) }

        should "include authorization code" do
          assert_match /[a-f0-9]{32}/i, @return["code"]
        end

        should "include original scope" do
          assert_equal "read write", @return["scope"]
        end

        should "include state from requet" do
          assert_equal "bring this back", @return["state"]
        end
      end
    end

    context "and denied" do
      setup { post "/oauth/deny" }

      should "redirect" do
        assert_equal 302, last_response.status
      end
      should "redirect back to client" do
        uri = URI.parse(last_response["Location"])
        assert_equal "uberclient.dot", uri.host
        assert_equal "/callback", uri.path
      end

      context "redirect URL" do
        setup { @return = Rack::Utils.parse_query(URI.parse(last_response["Location"]).query) }

        should "not include authorization code" do
          assert !@return["code"]
        end

        should "include error code" do
          assert_equal "access_denied", @return["error"]
        end

        should "include state from requet" do
          assert_equal "bring this back", @return["state"]
        end
      end
    end
  end


  context "expecting access token" do
    setup do
      @params[:response_type] = "token"
      request_authorization
    end
    should_ask_user_for_authorization

    context "and granted" do
      setup { post "/oauth/grant" }

      should "redirect" do
        assert_equal 302, last_response.status
      end
      should "redirect back to client" do
        uri = URI.parse(last_response["Location"])
        assert_equal "uberclient.dot", uri.host
        assert_equal "/callback", uri.path
      end

      context "redirect URL fragment identifier" do
        setup { @return = Rack::Utils.parse_query(URI.parse(last_response["Location"]).fragment) }

        should "include access token" do
          assert_match /[a-f0-9]{32}/i, @return["access_token"]
        end

        should "include original scope" do
          assert_equal "read write", @return["scope"]
        end

        should "include state from requet" do
          assert_equal "bring this back", @return["state"]
        end
      end
    end

    context "and denied" do
      setup { post "/oauth/deny" }

      should "redirect" do
        assert_equal 302, last_response.status
      end
      should "redirect back to client" do
        uri = URI.parse(last_response["Location"])
        assert_equal "uberclient.dot", uri.host
        assert_equal "/callback", uri.path
      end

      context "redirect URL" do
        setup { @return = Rack::Utils.parse_query(URI.parse(last_response["Location"]).query) }

        should "not include authorization code" do
          assert !@return["code"]
        end

        should "include error code" do
          assert_equal "access_denied", @return["error"]
        end

        should "include state from requet" do
          assert_equal "bring this back", @return["state"]
        end
      end
    end
  end


  # Edge cases

  context "unregistered redirect URI" do
    setup do
      Rack::OAuth2::Server::Client.collection.update({ :_id=>client._id }, { :$set=>{ :redirect_uri=>nil } })
      request_authorization :redirect_uri=>"http://uberclient.dot/oz"
    end
    should_ask_user_for_authorization
  end

end